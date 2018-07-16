#!/usr/bin/env bash

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

# This script is used to start a remote peer, in a different account/region to the main Fabric network.
# See the README in the remote-peer folder for details.

set -e

function main {
    echo "Beginning setup of remote peer on Hyperledger Fabric on Kubernetes ..."
    cd $HOME/$REPO
    mergeEnv
    source ../util-prep.sh
    updateRepo $HOME $REPO
    #makeDirs $DATADIR
    copyScripts $HOME $REPO $DATADIR
    cd $HOME/$REPO
    source scripts/env.sh
    source ../utilities.sh
    #makeDirsForOrg $DATADIR
    genTemplates $HOME $REPO
    genRemotePeers
    createNamespaces $HOME $REPO
    startPVC $HOME $REPO
    startRCA $HOME $REPO
    startICA $HOME $REPO
    startRegisterPeers $HOME $REPO
    startPeers $HOME $REPO
    whatsRunning
    echo "Setup of remote peer on Hyperledger Fabric on Kubernetes complete"
}

function mergeEnv {
    #merge the contents of the env.sh file
    #the env.sh in $SCRIPTS will have been updated with the DNS of the various endpoints, such as ORDERER and
    #ANCHOR PEER. We need to merge the contents of env-remote-peer.sh into $SCRIPTS/env.sh in order to retain
    #these DNS endpoints as they are used by the remote peer
    start='^##--BEGIN REPLACE CONTENTS--##$'
    end='^##--END REPLACE CONTENTS--##$'
    sed -e "/$start/,/$end/{ /$start/{p; r remote-peer/scripts/env-remote-peer.sh
        }; /$end/p; d }" $SCRIPTS/env.sh
    cp $SCRIPTS/env.sh scripts/env.sh
}

function genRemotePeers {
    cd $HOME/$REPO
    peerport=30750
    log "Generating Remote Peer K8s YAML files"
    for ORG in $PEER_ORGS; do
        getDomain $ORG
        local COUNT=1
        PORTCHAIN=$peerport
        while [[ "$COUNT" -le $NUM_PEERS ]]; do
            PORTCHAIN=$((PORTCHAIN+2))
            PORTEND=$((PORTCHAIN-1))
            sed -e "s/%PEER_NAME%/${PEER_NAME}/g" -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" -e "s/%NUM%/${COUNT}/g" -e "s/%PORTEND%/${PORTEND}/g" -e "s/%PORTCHAIN%/${PORTCHAIN}/g" remote-peer/k8s/fabric-deployment-remote-peer.yaml > k8s/fabric-deployment-remote-peer$COUNT-$PEER_NAME-$ORG.yaml
            COUNT=$((COUNT+1))
        done
        peerport=$((peerport+100))
   done
}

SDIR=$(dirname "$0")
DATADIR=/opt/share/
SCRIPTS=$DATADIR/rca-scripts
REPO=fabric-on-eks
main

