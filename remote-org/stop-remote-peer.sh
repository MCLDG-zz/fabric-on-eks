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

function main {
    log "Stopping remote peer on Hyperledger Fabric on Kubernetes ..."
    cd $HOME
    set +e
    stopTest $HOME $REPO
    for DELETE_ORG in $ORGS; do
        stopRemoteTest $HOME $REPO $DELETE_ORG
        stopRemotePeers $HOME $REPO $DELETE_ORG
        stopRegisterPeers $HOME $REPO $DELETE_ORG
        stopICA $HOME $REPO $DELETE_ORG
        stopRCA $HOME $REPO $DELETE_ORG
        stopPVC $HOME $REPO $DELETE_ORG
        getDomain $DELETE_ORG
        removeNamespaces $HOME $REPO $DOMAIN
        kubectl delete pv --all
    done
    removeDirs $DATA
    whatsRunning
    log "Hyperledger Fabric remote peer on Kubernetes stopped"
}

function stopRemotePeers {
    if [ $# -ne 3 ]; then
        echo "Usage: stopRemotePeers <home-dir> <repo-name> <delete-org>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    local ORG=$3
    cd $HOME
    log "Deleting Remote Peers in K8s"

    local COUNT=1
    while [[ "$COUNT" -le $NUM_PEERS ]]; do
        kubectl delete -f $REPO/k8s/fabric-deployment-remote-peer-${PEER_PREFIX}${COUNT}-$ORG.yaml
        COUNT=$((COUNT+1))
    done
    confirmDeploymentsStopped remote-peer
}

function stopRemoteTest {
    if [ $# -ne 3 ]; then
        echo "Usage: stopRemoteTest <home-dir> <repo-name> <delete-org>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    local ORG=$3
    cd $HOME
    log "Deleting Remote Test in K8s"

    kubectl delete -f $REPO/k8s/fabric-deployment-test-remote-fabric-marbles-$ORG.yaml
    confirmDeploymentsStopped test-remote-fabric

}

SDIR=$(dirname "$0")
DATA=/opt/share/
SCRIPTS=$DATA/rca-scripts
REPO=fabric-on-eks
cd $HOME/$REPO
source $SCRIPTS/env.sh
source utilities.sh
main
