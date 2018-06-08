#!/usr/bin/env bash

set -e

function main {
    echo "Beginning setup of Hyperledger Fabric on Kubernetes ..."
    cd $HOME/$REPO
    source util-prep.sh
    updateRepo $HOME $REPO
    makeDirs $DATADIR
    copyScripts $HOME $REPO $DATADIR
    source $SCRIPTS/env.sh
    cd $HOME/$REPO
    source utilities.sh
    makeDirsForOrg $DATADIR
    genTemplates $HOME $REPO
    createNamespaces $HOME $REPO
    startKafka $HOME $REPO
    startPVC $HOME $REPO
    startRCA $HOME $REPO
    startICA $HOME $REPO
    startRegisterOrderers $HOME $REPO
    startRegisterPeers $HOME $REPO
    updateChannelArtifacts $HOME $REPO
    startOrderer $HOME $REPO
    startPeers $HOME $REPO
    startTest $HOME $REPO
    whatsRunning
    echo "Setup of Hyperledger Fabric on Kubernetes complete"
}

SDIR=$(dirname "$0")
DATADIR=/opt/share/
SCRIPTS=$DATADIR/rca-scripts
REPO=fabric-on-eks
main

