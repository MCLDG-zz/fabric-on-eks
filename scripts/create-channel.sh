#!/bin/bash

set -e

source $(dirname "$0")/env.sh

function main {

   done=false

   log "Creating channel container started"

   # Set ORDERER_PORT_ARGS to the args needed to communicate with the 1st Orderer
   IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
   initOrdererVars ${OORGS[0]} 1
   export ORDERER_PORT_ARGS="-o $ORDERER_HOST:$ORDERER_PORT --tls --cafile $CA_CHAINFILE --clientauth"

   # Create the channel
   createChannel

   log "Congratulations! Channel created successfully."

   done=true
}

# Enroll as a peer admin in the org represented by $ORG and create the channel
function createChannel {
   #These ENV variables determine the channel name and the location where the channel TX file will be created
   export CHANNEL_NAME=testchannel2
   export CHANNEL_TX_FILE=/$DATA/$CHANNEL_NAME.tx
   cd $FABRIC_CFG_PATH
   cp /$DATA/configtx.yaml $FABRIC_CFG_PATH
   generateChannelArtifacts
   export ORG=org1
   log "Creating channel as peer1 in '$ORG'"
   initPeerVars ${ORG} 1
   switchToAdminIdentity
   log "Creating channel '$CHANNEL_NAME' with file '$CHANNEL_TX_FILE' on $ORDERER_HOST:$ORDERER_PORT using connection '$ORDERER_CONN_ARGS'"
   peer channel create --logging-level=DEBUG -c $CHANNEL_NAME -f $CHANNEL_TX_FILE $ORDERER_CONN_ARGS
   cp ${CHANNEL_NAME}.block /$DATA
}

function generateChannelArtifacts() {
  which configtxgen
  if [ "$?" -ne 0 ]; then
    fatal "configtxgen tool not found. exiting"
  fi

  log "Generating channel configuration transaction at $CHANNEL_TX_FILE"
  configtxgen -profile OrgsChannel -outputCreateChannelTx $CHANNEL_TX_FILE -channelID $CHANNEL_NAME
  if [ "$?" -ne 0 ]; then
    fatal "Failed to generate channel configuration transaction"
  fi

  for ORG in $PEER_ORGS; do
     initOrgVars $ORG
     ANCHOR_TX_FILE=/${DATA}/orgs/${ORG}/${CHANNEL_NAME}-anchors.tx

     log "Generating anchor peer update transaction for $ORG at $ANCHOR_TX_FILE"
     configtxgen -profile OrgsChannel -outputAnchorPeersUpdate $ANCHOR_TX_FILE \
                 -channelID $CHANNEL_NAME -asOrg $ORG
     if [ "$?" -ne 0 ]; then
        fatal "Failed to generate anchor peer update for $ORG"
     fi
  done
}

main
