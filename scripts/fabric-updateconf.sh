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
       echo "File '$file' exists - peer '$PEERORG' admin is updating channel config for for new/deleted org '$NEW_ORG'"
       cloneFabricSamples

       log "Signing the config for the new org '$NEW_ORG'"

       # Set ORDERER_PORT_ARGS to the args needed to communicate with the 1st orderer
       IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
       initOrdererVars ${OORGS[0]} 1
       export ORDERER_PORT_ARGS="-o $ORDERER_HOST:$ORDERER_PORT --tls --cafile $CA_CHAINFILE --clientauth"

       initPeerVars ${PEERORG} 1
       switchToAdminIdentity

       updateConfigBlock

       log "Congratulations! Config file has been updated on channel '$CHANNEL_NAME' by peer '$PEERORG' admin for the new/deleted org '$NEW_ORG'"
       log "You can now start the new peer, then join the new peer to the channel"
    else
        echo "File '$file' does not exist - no new org config will be updated - exiting"
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

function updateConfigBlock {
   log "Updating the configuration block of the channel '$CHANNEL_NAME' using config file /${DATA}/${NEW_ORG}_config_update_as_envelope.pb"
   peer channel update -f /${DATA}/${NEW_ORG}_config_update_as_envelope.pb -c $CHANNEL_NAME $ORDERER_CONN_ARGS
}

main
