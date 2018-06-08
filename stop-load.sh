#!/usr/bin/env bash

SDIR=$(dirname "$0")
DATA=/opt/share
SCRIPTS=$DATA/rca-scripts
source $SCRIPTS/env.sh
REPO=fabric-on-eks

function main {
    log "Stopping load of Hyperledger Fabric on Kubernetes ..."
    stopLoad
    whatsRunning
    log "Stopping of load Hyperledger Fabric on Kubernetes complete"
}

function stopLoad {
    log "Stopping Load Test in K8s"
    cd $HOME
    orgsarr=($PEER_ORGS)
    ORG=${orgsarr[0]}
    kubectl delete -f $REPO/k8s/fabric-deployment-load-fabric-$ORG.yaml
    confirmDeploymentsStopped load-fabric
}

function confirmDeploymentsStopped {
    if [ $# -ne 1 ]; then
        echo "Usage: confirmDeploymentsStopped <deployment>"
        exit 1
    fi
    DEPLOY=$1

    log "Checking whether all pods have stopped"

    for ORG in $ORGS; do
        NUMPENDING=$(kubectl get po -n $ORG | grep $DEPLOY | awk '{print $5}' | wc -l | awk '{print $1}')
        while [ "${NUMPENDING}" != "0" ]; do
            echo "Waiting on deployments in namespace $ORG to stop. Deployments pending = ${NUMPENDING}"
            NUMPENDING=$(kubectl get po -n $ORG | grep $DEPLOY | awk '{print $5}' | wc -l | awk '{print $1}')
            sleep 3
        done
    done
}

function whatsRunning {
    log "Check what is running"
    for ORG in $ORGS; do
        kubectl get deploy -n $ORG
        kubectl get po -n $ORG
    done
}

main

