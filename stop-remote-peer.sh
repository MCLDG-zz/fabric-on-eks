#!/usr/bin/env bash

function main {
    log "Stopping remote peer on Hyperledger Fabric on Kubernetes ..."
    cd $HOME
    set +e
    stopTest $HOME $REPO
    for DELETE_ORG in $ORGS; do
        stopPeers $HOME $REPO $DELETE_ORG
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

SDIR=$(dirname "$0")
SCRIPTS=$DATA/rca-scripts
source $SCRIPTS/env.sh
source $SDIR/utilities.sh
DATA=/opt/share/
REPO=fabric-on-eks
main
