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

set +e

source $(dirname "$0")/env.sh

function main {

   done=false

   cloneFabricSamples

   log "Test network using marbles chaincode"

   # Set ORDERER_PORT_ARGS to the args needed to communicate with the 1st orderer
   IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
   initOrdererVars ${OORGS[0]} 1
   export ORDERER_PORT_ARGS="-o $ORDERER_HOST:$ORDERER_PORT --tls --cafile $CA_CHAINFILE --clientauth"
#   export ORDERER_PORT_ARGS="-o $ORDERER_HOST:7050 --cafile $CA_CHAINFILE"

   # Convert PEER_ORGS to an array named PORGS
   IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"

   # Create the channel
   createChannel

   # All peers join the channel
   for ORG in $PEER_ORGS; do
      local COUNT=1
      while [[ "$COUNT" -le $NUM_PEERS ]]; do
         initPeerVars $ORG $COUNT
         joinChannel
         COUNT=$((COUNT+1))
      done
   done

   # Update the anchor peers
   for ORG in $PEER_ORGS; do
      initPeerVars $ORG 1
      switchToAdminIdentity
      log "Updating anchor peers for $PEER_NAME ..."
      peer channel update -c $CHANNEL_NAME -f $ANCHOR_TX_FILE $ORDERER_CONN_ARGS
   done

   # Install chaincode on the 1st peer in each org
   for ORG in $PEER_ORGS; do
      initPeerVars $ORG 1
      installChaincode
   done

   # Instantiate chaincode on the 1st peer of the 2nd org
   makePolicy
   initPeerVars ${PORGS[1]} 1
   instantiateChaincode

   # Query chaincode from the 1st peer of the 1st org
   initPeerVars ${PORGS[0]} 1
   switchToUserIdentity
   sleep 5
   chaincodeInit
   sleep 5
   chaincodeQuery

   # Invoke chaincode on the 1st peer of the 1st org
   initPeerVars ${PORGS[0]} 1
   switchToUserIdentity
   transferMarble

   ## Install chaincode on 2nd peer of 2nd org
   initPeerVars ${PORGS[1]} 2
   installChaincode

   # Query chaincode on 2nd peer of 2nd org
   sleep 10
   initPeerVars ${PORGS[1]} 2
   switchToUserIdentity
   chaincodeQuery

   log "Congratulations! Marble chaincode tests ran successfully."

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

# Enroll as a peer admin and create the channel
function createChannel {
   initPeerVars ${PORGS[0]} 1
   switchToAdminIdentity
   log "Creating channel '$CHANNEL_NAME' with file '$CHANNEL_TX_FILE' on $ORDERER_HOST using connection '$ORDERER_CONN_ARGS'"
   peer channel create --logging-level=DEBUG -c $CHANNEL_NAME -f $CHANNEL_TX_FILE $ORDERER_CONN_ARGS
   cp ${CHANNEL_NAME}.block /$DATA
}

# Enroll as a fabric admin and join the channel
function joinChannel {
   switchToAdminIdentity
   set +e
   local COUNT=1
   MAX_RETRY=10
   while true; do
      log "Peer $PEER_NAME is attempting to join channel '$CHANNEL_NAME' (attempt #${COUNT}) ..."
      peer channel join -b $CHANNEL_NAME.block
      if [ $? -eq 0 ]; then
         set -e
         log "Peer $PEER_NAME successfully joined channel '$CHANNEL_NAME'"
         return
      fi
      if [ $COUNT -gt $MAX_RETRY ]; then
         fatalr "Peer $PEER_NAME failed to join channel '$CHANNEL_NAME' in $MAX_RETRY retries"
      fi
      COUNT=$((COUNT+1))
      sleep 1
   done
}

function installChaincode {
   switchToAdminIdentity
   log "Installing chaincode on $PEER_NAME ..."
   peer chaincode install -n marblescc -v 1.0 -p github.com/hyperledger/fabric-samples/chaincode/marbles02/go
}

function instantiateChaincode {
   switchToAdminIdentity
   log "Instantiating marbles chaincode on $PEER_HOST ..."
   peer chaincode instantiate -C $CHANNEL_NAME -n marblescc -v 1.0 -c '{"Args":["init"]}' -P "$POLICY" $ORDERER_CONN_ARGS
}

function chaincodeInit {
   log "Initialising marbles on $PEER_NAME ..."
   peer chaincode invoke -C $CHANNEL_NAME -n marblescc -c '{"Args":["initMarble","marble1","blue","21","edge"]}' $ORDERER_CONN_ARGS
   peer chaincode invoke -C $CHANNEL_NAME -n marblescc -c '{"Args":["initMarble","marble2","red","27","braendle"]}' $ORDERER_CONN_ARGS
}

function chaincodeQuery {
   set +e
   log "Querying marbles chaincode in the channel '$CHANNEL_NAME' on the peer '$PEER_NAME' ..."
   peer chaincode query -C $CHANNEL_NAME -n marblescc -c '{"Args":["readMarble","marble1"]}' >& log.txt
   cat log.txt
   peer chaincode query -C $CHANNEL_NAME -n marblescc -c '{"Args":["readMarble","marble2"]}' >& log.txt
   cat log.txt
   log "Successfully queried marbles chaincode in the channel '$CHANNEL_NAME' on the peer '$PEER_NAME' ..."
}

function transferMarble {
   set +e
   log "Transferring marbles in the channel '$CHANNEL_NAME' on the peer '$PEER_NAME' ..."
   peer chaincode invoke -C $CHANNEL_NAME -n marblescc -c '{"Args":["transferMarble","marble2","edge"]}' $ORDERER_CONN_ARGS
   log "Successfully transferred marbles in the channel '$CHANNEL_NAME' on the peer '$PEER_NAME' ..."
}

function makePolicy  {
   POLICY="OR("
   local COUNT=0
   for ORG in $PEER_ORGS; do
      if [ $COUNT -ne 0 ]; then
         POLICY="${POLICY},"
      fi
      initOrgVars $ORG
      POLICY="${POLICY}'${ORG_MSP_ID}.member'"
      COUNT=$((COUNT+1))
   done
   POLICY="${POLICY})"
   log "policy: $POLICY"
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
