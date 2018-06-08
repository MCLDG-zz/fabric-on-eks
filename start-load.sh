#!/usr/bin/env bash

set -e

SDIR=$(dirname "$0")
DATA=/opt/share
SCRIPTS=$DATA/rca-scripts
source $SCRIPTS/env.sh
REPO=fabric-on-eks

function main {
    log "Beginning setup of Hyperledger Fabric on Kubernetes ..."
    startLoad
    whatsRunning
    log "Setup of Hyperledger Fabric on Kubernetes complete"
}

function startLoad {
    log "Starting Load Test in K8s"
    cd $HOME
    orgsarr=($PEER_ORGS)
    ORG=${orgsarr[0]}
    kubectl apply -f $REPO/k8s/fabric-deployment-load-fabric-$ORG.yaml
    confirmDeployments
}

function confirmDeployments {
    log "Checking whether all deployments are ready"

    for ORG in $ORGS; do
        NUMPENDING=$(kubectl get deployments -n $ORG | awk '{print $5}' | grep 0 | wc -l | awk '{print $1}')
        while [ "${NUMPENDING}" != "0" ]; do
            echo "Waiting on pending deployments in namespace $ORG. Deployments pending = ${NUMPENDING}"
            NUMPENDING=$(kubectl get deployments -n $ORG | awk '{print $5}' | grep 0 | wc -l | awk '{print $1}')
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

