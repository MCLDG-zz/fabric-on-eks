#!/bin/bash

# Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this
# software and associated documentation files (the "Software"), to deal in the Software
# without restriction, including without limitation the rights to use, copy, modify,
# merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#
# This script does the following:
# 1) registers peers with intermediate fabric-ca-servers
#

function main {
   log "Registering identities ..."
   registerIdentities
   getCACerts
   log "Finished registering identities"
}

# Enroll the CA administrator
function enrollCAAdmin {
   log "Enrolling with $CA_NAME as bootstrap identity ..."
   export FABRIC_CA_CLIENT_HOME=$HOME/cas/$CA_NAME
   export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE
   fabric-ca-client enroll -d -u https://$CA_ADMIN_USER_PASS@$CA_HOST:7054
}

function registerIdentities {
   log "Registering identities ..."
   registerPeerIdentities
}

# Register any identities associated with a peer
function registerPeerIdentities {
    export ORG=$PEERORG
    log "Registering peer $PEER_NAME with org: $ORG"
    initOrgVars $ORG
    enrollCAAdmin
    local COUNT=1
    while [[ "$COUNT" -le $NUM_PEERS ]]; do
        initPeerVars $ORG $COUNT
        log "Registering $PEER_NAME with $CA_NAME"
        fabric-ca-client register -d --id.name $PEER_NAME --id.secret $PEER_PASS --id.type peer
        COUNT=$((COUNT+1))
    done
    log "Registering admin identity with $CA_NAME"
    # The admin identity has the "admin" attribute which is added to ECert by default
    fabric-ca-client register -d --id.name $ADMIN_NAME --id.secret $ADMIN_PASS --id.attrs "hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert"
    log "Registering user identity with $CA_NAME"
    fabric-ca-client register -d --id.name $USER_NAME --id.secret $USER_PASS

}

function getCACerts {
    export ORG=$PEERORG
    log "Getting CA certificates for peer $ORG"
    initOrgVars $ORG
    log "Getting CA certs for organization $ORG and storing in $ORG_MSP_DIR"
    export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE
    fabric-ca-client getcacert -d -u https://$CA_HOST:7054 -M $ORG_MSP_DIR
    finishMSPSetup $ORG_MSP_DIR
    # If ADMINCERTS is true, we need to enroll the admin now to populate the admincerts directory
    if [ $ADMINCERTS ]; then
        switchToAdminIdentity
    fi
}

set -e

SDIR=$(dirname "$0")
source $SDIR/env.sh

main
