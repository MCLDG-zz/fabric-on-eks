#!/usr/bin/env bash

SDIR=$(dirname "$0")
DATA=/opt/share
SCRIPTS=$DATA/rca-scripts
source $SCRIPTS/env.sh
source $SDIR/utilities.sh

function signConfOrgFabric {
    if [ $# -lt 2 ]; then
        echo "Usage: signConfOrgFabric <home-dir> <repo-name> <new-org - an org if we are adding a new org, otherwise leave blank>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    local NEWORG=$3

    log "Signing org config for Fabric in K8s"
    cd $HOME
    # the other peer admins must sign the new org config update.
    for ORG in $PEER_ORGS; do
        #config update can't be signed and updated by the new org, if we are adding one, so skip it
        if [[ "$ORG" == "$NEWORG" ]]; then
            continue
        fi
        log "'$ORG' is signing the config update"
        getDomain $ORG
        kubectl apply -f $REPO/k8s/fabric-job-signconf-$ORG.yaml --namespace $DOMAIN
        confirmJobs "fabric-signconf"
        if [ $? -eq 1 ]; then
            log "Job fabric-job-signconf-$ORG.yaml failed; exiting"
            exit 1
        fi
        #domain is overwritten by confirmJobs, so we look it up again
        getDomain $ORG
        # check whether the signing of the org config has completed
        for i in {1..10}; do
            if kubectl logs jobs/fabric-signconf --namespace $DOMAIN --tail=10 | grep -q "Congratulations! The config file has been signed"; then
                log "Org configuration signed by fabric-job-signconf-$ORG.yaml"
                break
            else
                log "Waiting for fabric-job-signconf-$ORG.yaml to complete"
                sleep 5
            fi
        done
    done
}

function updateConfOrgFabric {
    if [ $# -ne 3 ]; then
        echo "Usage: updateConfOrgFabric <home-dir> <repo-name> <admin-org possibly the first org in the network, where we carry out admin tasks>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    local ADMINORG=$3

    log "Updating channel config for Fabric in K8s"
    cd $HOME

    getDomain $ADMINORG
    echo "UpdateConf for org '$ADMINORG' in namespace '$DOMAIN'"
    kubectl apply -f $REPO/k8s/fabric-job-updateconf-$ADMINORG.yaml --namespace $DOMAIN
    confirmJobs "fabric-updateconf"
    if [ $? -eq 1 ]; then
        log "Job fabric-job-updateconf-$ADMINORG.yaml failed; exiting"
        exit 1
    fi

    #domain is overwritten by confirmJobs, so we look it up again
    getDomain $ADMINORG
    # check whether the update of the org config has completed
    for i in {1..10}; do
        if kubectl logs jobs/fabric-updateconf --namespace $DOMAIN --tail=10 | grep -q "Congratulations! Config file has been updated on channel"; then
            log "Org configuration updated by fabric-job-updateconf-$ADMINORG.yaml"
            break
        else
            log "Waiting for fabric-job-updateconf-$ADMINORG.yaml to complete"
            sleep 5
        fi
    done
}

