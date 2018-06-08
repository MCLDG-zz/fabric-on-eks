#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

source $(dirname "$0")/env.sh

function main {

   done=false

    file=/${DATA}/updateorg
    if [ -f "$file" ]; then
       NEW_ORG=$(cat $file)
       echo "File '$file' exists - peer '$PEERORG' admin is signing new org config for new/deleted org '$NEW_ORG'"
       cloneFabricSamples

       log "Signing the config for the new org '$NEW_ORG'"

       # Set ORDERER_PORT_ARGS to the args needed to communicate with the 1st orderer
       IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
       initOrdererVars ${OORGS[0]} 1
       export ORDERER_PORT_ARGS="-o $ORDERER_HOST:$ORDERER_PORT --tls --cafile $CA_CHAINFILE --clientauth"

       initPeerVars ${PEERORG} 1
       switchToAdminIdentity

       # Sign the config update
       signConfigUpdate

       log "Congratulations! The config file has been signed by peer '$PEERORG' admin for the new/deleted org '$NEW_ORG'"
    else
        echo "File '$file' does not exist - no new org config will be signed - exiting"
        exit 1
    fi

   done=true
}

# git clone fabric-samples. We need this repo for the chaincode
function cloneFabricSamples {
   log "cloneFabricSamples"
   mkdir -p /opt/gopath/src/github.com/hyperledger
   cd /opt/gopath/src/github.com/hyperledger
   git clone https://github.com/hyperledger/fabric-samples.git
   log "cloned FabricSamples"
   cd fabric-samples
   git checkout release-1.1
   log "checked out version 1.1 of FabricSamples"

   log "cloneFabric"
   mkdir /opt/gopath/src/github.com/hyperledger/fabric
}

# Signing must be done by the majority of peer admins. In this case, we sign the update as peer1, then store the
# signed config file in the /data directory. Another K8s pod running as peer2 will wait for the file to appear,
# and sign it as peer2. This represents a real world scenario, where the config update would need to be signed by
# different admins before it can be deployed.
function signConfigUpdate {
   log "Signing the configuration block of the channel '$CHANNEL_NAME' in config file /${DATA}/${NEW_ORG}_config_update_as_envelope.pb"
   peer channel signconfigtx -f /${DATA}/${NEW_ORG}_config_update_as_envelope.pb
}

main
