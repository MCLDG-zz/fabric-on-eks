#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

source $(dirname "$0")/env.sh

# If a peer crashes and restarts, it must be configured to join the channel. To do this,
# edit the generated K8s YAML file fabric-deployment-peer-join-channel<number> and change the values for ORG and NUM,
# including the namespace and other params.
# Then do a kubectl apply on this file. This will configure the peer referred to by these values to join the channel.
function main {

    done=false

    cloneFabricSamples

    log "Peer for '$ORG' is joining channel '$CHANNEL_NAME'"

    # Specific peer joins the channel
    export ORG=$PEERORG
    export PEERNUM=$PEERNUM
    initPeerVars $ORG $PEERNUM
    joinChannel
    # Install chaincode on the 1st peer in each org
    if [ $PEERNUM -eq 1 ]; then
      installChaincode
    fi

    log "Congratulations! The peer has joined the channel."

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

# Enroll as a fabric admin and join the channel
function joinChannel {
   switchToAdminIdentity
   set +e
   local COUNT=1
   MAX_RETRY=10
   while true; do
      log "Peer $PEER_HOST is attempting to join channel '$CHANNEL_NAME' (attempt #${COUNT}) ..."
      peer channel join -b /$DATA/$CHANNEL_NAME.block
      if [ $? -eq 0 ]; then
         set -e
         log "Peer $PEER_HOST successfully joined channel '$CHANNEL_NAME'"
         return
      fi
      if [ $COUNT -gt $MAX_RETRY ]; then
         fatalr "Peer $PEER_HOST failed to join channel '$CHANNEL_NAME' in $MAX_RETRY retries"
      fi
      COUNT=$((COUNT+1))
      sleep 1
   done
}


function installChaincode {
   switchToAdminIdentity
   log "Installing chaincode on $PEER_HOST ..."
   peer chaincode install -n mycc -v 1.0 -p github.com/hyperledger/fabric-samples/chaincode/abac/go
}
function finish {
   if [ "$done" = true ]; then
      log "See $RUN_LOGFILE for more details"
      touch /$RUN_SUCCESS_FILE
   else
      log "Tests did not complete successfully; see $RUN_LOGFILE for more details"
      touch /$RUN_FAIL_FILE
   fi
}

function fatalr {
   log "FATAL: $*"
   exit 1
}

main
