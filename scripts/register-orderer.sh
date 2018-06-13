#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

#
# This script does the following:
# 1) registers orderer with intermediate fabric-ca-servers
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
   registerOrdererIdentities
}

# Register any identities associated with the orderer
function registerOrdererIdentities {
    export ORG=$ORDERERORG
    log "Registering orderer: $ORG"
    initOrgVars $ORG
    enrollCAAdmin
    local COUNT=1
    while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
        initOrdererVars $ORG $COUNT
        log "Registering $ORDERER_NAME with $CA_NAME"
        fabric-ca-client register -d --id.name $ORDERER_NAME --id.secret $ORDERER_PASS --id.type orderer
        COUNT=$((COUNT+1))
    done
    log "Registering admin identity with $CA_NAME"
    # The admin identity has the "admin" attribute which is added to ECert by default
    fabric-ca-client register -d --id.name $ADMIN_NAME --id.secret $ADMIN_PASS --id.attrs "admin=true:ecert"
}

function getCACerts {
    export ORG=$ORDERERORG
    log "Getting CA certificates for orderer $ORG"
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

set +e

SDIR=$(dirname "$0")
source $SDIR/env.sh

main
