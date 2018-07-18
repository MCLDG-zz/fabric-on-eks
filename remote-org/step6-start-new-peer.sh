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

set -e

function main {
    echo "Step6: start new peer ..."
    cd $HOME/$REPO
    startRegisterPeers $HOME $REPO
    startRemotePeers $HOME $REPO
    echo "Step6: start new peer complete"
}

function startRemotePeers {
    if [ $# -ne 2 ]; then
        echo "Usage: startRemotePeers <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    cd $HOME
    log "Starting Remote Peers in K8s"

    for ORG in $PEER_ORGS; do
      local COUNT=1
      while [[ "$COUNT" -le $NUM_PEERS ]]; do
        kubectl apply -f $REPO/k8s/fabric-deployment-remote-peer-${PEER_PREFIX}${COUNT}-$ORG.yaml
        COUNT=$((COUNT+1))
      done
    done
    confirmDeployments
}

SDIR=$(dirname "$0")
DATADIR=/opt/share/
SCRIPTS=$DATADIR/rca-scripts
REPO=fabric-on-eks
source $SCRIPTS/env.sh
source $HOME/$REPO/utilities.sh
main

