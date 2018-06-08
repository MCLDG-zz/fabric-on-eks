#!/usr/bin/env bash

function main {
    log "Stopping Hyperledger Fabric on Kubernetes ..."
    cd $HOME
    stopJobsFabric $HOME $REPO
    set +e
    stopTest $HOME $REPO
    stopChannelArtifacts $HOME $REPO
    stopRegisterOrderers $HOME $REPO
    stopOrderer $HOME $REPO
    stopKafka $HOME $REPO
    for DELETE_ORG in $ORGS; do
        stopPeers $HOME $REPO $DELETE_ORG
        stopRegisterPeers $HOME $REPO $DELETE_ORG
        stopICA $HOME $REPO $DELETE_ORG
        stopRCA $HOME $REPO $DELETE_ORG
        stopPVC $HOME $REPO $DELETE_ORG
        getDomain $DELETE_ORG
        removeNamespaces $HOME $REPO $DOMAIN
    done
    removeDirs $DATA
    whatsRunning
    log "Hyperledger Fabric on Kubernetes stopped"
}

SDIR=$(dirname "$0")
SCRIPTS=$DATA/rca-scripts
source $SCRIPTS/env.sh
source $SDIR/utilities.sh
DATA=/opt/share/
REPO=fabric-ca-sample
main
