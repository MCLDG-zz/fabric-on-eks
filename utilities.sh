#!/usr/bin/env bash

DATA=/opt/share
SCRIPTS=$DATA/rca-scripts
source $SCRIPTS/env.sh

function removeDirs {
    if [ $# -ne 1 ]; then
        echo "Usage: removeDirs <data-dir - probably something like /opt/share>"
        echo "input args are '$@'"
        exit 1
    fi
    local DATA=$1
    log "Removing directories at $DATA"
    cd $DATA
    sudo rm -rf rca-data
    sudo rm -rf rca-scripts
    sudo rm -rf orderer
    for ORG in $ORGS; do
        sudo rm -rf rca-$ORG
        sudo rm -rf ica-$ORG
    done
}

function makeDirsForOrg {
    if [ $# -ne 1 ]; then
        echo "Usage: makeDirs <data-dir - probably something like /opt/share>"
        echo "input args are '$@'"
        exit 1
    fi
    local DATA=$1
    echo "Making directories at $DATA"
    cd $DATA
    for ORG in $ORGS; do
        mkdir -p rca-$ORG
        mkdir -p ica-$ORG
    done
}

function removeDirsForOrg {
    if [ $# -ne 2 ]; then
        echo "Usage: removeDirsForOrg <data-dir - probably something like /opt/share> <org - org to delete>"
        exit 1
    fi
    local DATA=$1
    local ORG=$2
    log "Removing '$ORG' directories at $DATA"
    cd $DATA
    sudo rm -rf rca-data/orgs/$ORG
    sudo rm -rf rca-data/${ORG}*
    sudo rm -rf rca-$ORG
    sudo rm -rf ica-$ORG
}

function createNamespaces {
    if [ $# -ne 2 ]; then
        echo "Usage: createNamespaces <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    log "Creating K8s namespaces"
    cd $HOME
    for ORG in $ORGS; do
        kubectl apply -f $REPO/k8s/fabric-namespace-$ORG.yaml
    done
}

function startPVC {
    if [ $# -ne 2 ]; then
        echo "Usage: startPVC <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    log "Starting PVC in K8s"
    cd $HOME
    for ORG in $ORGS; do
        kubectl apply -f $REPO/k8s/fabric-pvc-rca-scripts-$ORG.yaml
        kubectl apply -f $REPO/k8s/fabric-pvc-rca-data-$ORG.yaml
        kubectl apply -f $REPO/k8s/fabric-pvc-rca-$ORG.yaml
        kubectl apply -f $REPO/k8s/fabric-pvc-ica-$ORG.yaml
        sleep 2
    done
    for ORG in $ORDERER_ORGS; do
        kubectl apply -f $REPO/k8s/fabric-pvc-orderer-$ORG.yaml
    done
}

function startRCA {
    if [ $# -ne 2 ]; then
        echo "Usage: startRCA <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    cd $HOME
    log "Starting RCA in K8s"
    for ORG in $ORGS; do
        kubectl apply -f $REPO/k8s/fabric-deployment-rca-$ORG.yaml
    done
    #make sure the svc starts, otherwise subsequent commands may fail
    confirmDeployments
}

function startICA {
    if [ $# -ne 2 ]; then
        echo "Usage: startICA <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    cd $HOME
    log "Starting ICA in K8s"
    for ORG in $ORGS; do
        kubectl apply -f $REPO/k8s/fabric-deployment-ica-$ORG.yaml
    done
    #make sure the svc starts, otherwise subsequent commands may fail
    confirmDeployments
}

function removeNamespaces {
    if [ $# -ne 3 ]; then
        echo "Usage: removeNamespaces <home-dir> <repo-name> <domain - delete namespace where namespace = domain. Example of a domain would be org2>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    local DOMAIN=$3
    log "Deleting K8s namespaces for domain: '$DOMAIN'"
    cd $HOME
    kubectl delete -f $REPO/k8s/fabric-namespace-$DOMAIN.yaml
}

function stopPVC {
    if [ $# -ne 3 ]; then
        echo "Usage: stopPVC <home-dir> <repo-name> <org>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    local ORG=$3
    log "Stopping PVC in K8s"
    cd $HOME
    kubectl delete -f $REPO/k8s/fabric-pvc-rca-scripts-$ORG.yaml
    kubectl delete -f $REPO/k8s/fabric-pvc-rca-data-$ORG.yaml
    kubectl delete -f $REPO/k8s/fabric-pvc-rca-$ORG.yaml
    kubectl delete -f $REPO/k8s/fabric-pvc-ica-$ORG.yaml
    kubectl delete -f $REPO/k8s/fabric-pvc-orderer-$ORG.yaml
}

function stopRCA {
    if [ $# -ne 3 ]; then
        echo "Usage: stopRCA <home-dir> <repo-name> <org>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    local ORG=$3
    log "Stopping RCA in K8s"
    cd $HOME
    kubectl delete -f $REPO/k8s/fabric-deployment-rca-$ORG.yaml
    confirmDeploymentsStopped rca $ORG
}

function stopICA {
    if [ $# -ne 3 ]; then
        echo "Usage: stopICA <home-dir> <repo-name> <org>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    local ORG=$3
    log "Stopping ICA in K8s"
    cd $HOME
    kubectl delete -f $REPO/k8s/fabric-deployment-ica-$ORG.yaml
    confirmDeploymentsStopped ica $ORG
}

function stopRegisterOrderers {
    if [ $# -ne 2 ]; then
        echo "Usage: stopRegisterOrderers <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    cd $HOME
    log "Stopping Registering Fabric Orderers"
    for ORG in $ORDERER_ORGS; do
            kubectl delete -f $REPO/k8s/fabric-deployment-register-orderer-$ORG.yaml
    done
    confirmDeploymentsStopped register-o
}

function stopRegisterPeers {
    if [ $# -ne 3 ]; then
        echo "Usage: stopRegisterPeers <home-dir> <repo-name> <org>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    local ORG=$3
    log "Stopping Registering Fabric Peers"
    cd $HOME
    kubectl delete -f $REPO/k8s/fabric-deployment-register-peer-$ORG.yaml
    confirmDeploymentsStopped register-p $ORG
}

function stopPeers {
    if [ $# -ne 3 ]; then
        echo "Usage: stopPeers <home-dir> <repo-name> <org>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    local ORG=$3
    log "Stopping Peers in K8s"
    cd $HOME
    local COUNT=1
    while [[ "$COUNT" -le $NUM_PEERS ]]; do
        kubectl delete -f $REPO/k8s/fabric-deployment-peer$COUNT-$ORG.yaml
        COUNT=$((COUNT+1))
    done
    confirmDeploymentsStopped peer $ORG
}

function stopKafka {
    if [ $# -ne 2 ]; then
        echo "Usage: stopKafka <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    cd $HOME
    log "Checking whether to stop Kafa. ORDERER_TYPE is $ORDERER_TYPE"
    if [[ "$ORDERER_TYPE" == "kafka" ]]; then
        log "Stopping Kafa"
        $REPO/stop-kafka.sh
    fi
}

function stopOrderer {
    if [ $# -ne 2 ]; then
        echo "Usage: stopOrderer <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    cd $HOME
    log "Stopping Orderer in K8s"
    for ORG in $ORDERER_ORGS; do
      local COUNT=1
      while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
         kubectl delete -f $REPO/k8s/fabric-deployment-orderer$COUNT-$ORG.yaml
         COUNT=$((COUNT+1))
      done
    done
    confirmDeploymentsStopped orderer
}

function stopTest {
    if [ $# -ne 2 ]; then
        echo "Usage: stopTest <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    cd $HOME
    log "Stopping Test Cases in K8s"
    kubectl delete -f $REPO/k8s/fabric-deployment-test-fabric.yaml
    log "Confirm Test Case pod has stopped"
    confirmDeploymentsStopped test-fabric
}

function stopChannelArtifacts {
    if [ $# -ne 2 ]; then
        echo "Usage: stopChannelArtifacts <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    cd $HOME
    log "Stopping Fabric Channel Artifacts"
    kubectl delete -f $REPO/k8s/fabric-deployment-channel-artifacts.yaml
    confirmDeploymentsStopped channel-artifacts
}

function updateChannelArtifacts {
    set +e
    if [ $# -ne 2 ]; then
        echo "Usage: updateChannelArtifacts <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    log "Generating Fabric Channel Artifacts"
    #stop the existing channel artifacts pod. Restart it to regenerate a new configtx.yaml
    #and new artifacts
    cd $HOME
    stopChannelArtifacts $HOME $REPO
    sleep 5
    kubectl apply -f $REPO/k8s/fabric-deployment-channel-artifacts.yaml
    confirmDeployments
    set -e
}

function joinaddorgFabric {
    if [ $# -ne 3 ]; then
        echo "Usage: joinaddorgFabric <home-dir> <repo-name> <new org - the new org joining the channel>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    local NEW_ORG=$3
    log "Joining new org '$NEW_ORG' to the channel"
    cd $HOME
    getDomain $NEW_ORG
    kubectl apply -f $REPO/k8s/fabric-job-addorg-join-$NEW_ORG.yaml --namespace $DOMAIN
    confirmJobs "addorg-fabric-join"
    if [ $? -eq 1 ]; then
        log "Job fabric-job-addorg-join-$NEW_ORG.yaml failed; exiting"
        exit 1
    fi
    #domain is overwritten by confirmJobs, so we look it up again
    getDomain $NEW_ORG
    for i in {1..10}; do
        if kubectl logs jobs/addorg-fabric-join --namespace $DOMAIN --tail=10 | grep -q "Congratulations! The new org has joined the channel"; then
            log "New org joined the channel by fabric-job-addorg-join-$NEW_ORG.yaml"
            break
        else
            log "Waiting for fabric-job-addorg-join-$NEW_ORG.yaml to complete"
            sleep 5
        fi
    done
}

function startRegisterOrderers {
    if [ $# -ne 2 ]; then
        echo "Usage: startRegisterOrderers <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    cd $HOME
    log "Registering Fabric Orderers"
    for ORG in $ORDERER_ORGS; do
            kubectl apply -f $REPO/k8s/fabric-deployment-register-orderer-$ORG.yaml
    done
    confirmDeployments
}

function startRegisterPeers {
    if [ $# -ne 2 ]; then
        echo "Usage: startRegisterPeers <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    cd $HOME
    log "Registering Fabric Peers"
    for ORG in $PEER_ORGS; do
         kubectl apply -f $REPO/k8s/fabric-deployment-register-peer-$ORG.yaml
   done
   confirmDeployments
}

function startKafka {
    if [ $# -ne 2 ]; then
        echo "Usage: startKafka <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    cd $HOME
    log "Checking whether to start Kafa. ORDERER_TYPE is $ORDERER_TYPE"
    if [[ "$ORDERER_TYPE" == "kafka" ]]; then
        log "Starting Kafa"
#        ./$REPO/start-kafka.sh
    fi
}

function startOrderer {
    if [ $# -ne 2 ]; then
        echo "Usage: startOrderer <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    cd $HOME
    log "Starting Orderer in K8s"
    for ORG in $ORDERER_ORGS; do
      local COUNT=1
      while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
        kubectl apply -f $REPO/k8s/fabric-deployment-orderer$COUNT-$ORG.yaml
        COUNT=$((COUNT+1))
      done
    done
    confirmDeployments
}

function startPeers {
    if [ $# -ne 2 ]; then
        echo "Usage: startPeers <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    cd $HOME
    log "Starting Peers in K8s"
    for ORG in $PEER_ORGS; do
      local COUNT=1
      while [[ "$COUNT" -le $NUM_PEERS ]]; do
         kubectl apply -f $REPO/k8s/fabric-deployment-peer$COUNT-$ORG.yaml
         COUNT=$((COUNT+1))
      done
   done
   confirmDeployments
}

function startTest {
    if [ $# -ne 2 ]; then
        echo "Usage: startTest <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    cd $HOME
    log "Starting Test Cases in K8s"
    kubectl apply -f $REPO/k8s/fabric-deployment-test-fabric.yaml
    confirmDeployments
}


function getAdminOrg {
    peerorgs=($PEER_ORGS)
    ADMINORG=${peerorgs[0]}
}

function stopJobsFabric {
    if [ $# -ne 2 ]; then
        echo "Usage: stopJobsFabric <home-dir> <repo-name>"
        exit 1
    fi
    local HOME=$1
    local REPO=$2
    cd $HOME
    log "Stopping Jobs on Fabric in K8s"
    set +e
    # we take a brute-force approach here and just delete all the jobs, even though not all jobs
    # run in all org namespaces. Since there is no 'set -e' in this script, it will continue
    # if there are errors
    for ORG in $PEER_ORGS; do
        getDomain $ORG
        kubectl delete -f $REPO/k8s/fabric-job-upgradecc-$ORG.yaml --namespace $DOMAIN
        kubectl delete -f $REPO/k8s/fabric-job-installcc-$ORG.yaml --namespace $DOMAIN
        kubectl delete -f $REPO/k8s/fabric-job-addorg-join-$ORG.yaml --namespace $DOMAIN
        kubectl delete -f $REPO/k8s/fabric-job-updateconf-$ORG.yaml --namespace $DOMAIN
        kubectl delete -f $REPO/k8s/fabric-job-signconf-$ORG.yaml --namespace $DOMAIN
        kubectl delete -f $REPO/k8s/fabric-job-addorg-setup-$ORG.yaml --namespace $DOMAIN
        kubectl delete -f $REPO/k8s/fabric-job-delete-org-$ORG.yaml --namespace $DOMAIN
    done

    confirmDeploymentsStopped addorg-fabric-setup
    confirmDeploymentsStopped fabric-sign
    confirmDeploymentsStopped fabric-updateconf
    confirmDeploymentsStopped addorg-fabric-join
    confirmDeploymentsStopped fabric-installcc
    confirmDeploymentsStopped fabric-upgradecc
    confirmDeploymentsStopped fabric-delete-org
}

function confirmJobs {
    log "Checking whether all jobs are ready"

    for TMPORG in $ORGS; do
        getDomain $TMPORG
        NUMPENDING=$(kubectl get jobs --namespace $DOMAIN | awk '{print $3}' | grep 0 | wc -l | awk '{print $1}')
        local COUNT=1
        while [ "${NUMPENDING}" != "0" ]; do
            echo "Waiting on pending jobs in namespace '$DOMAIN'. Jobs pending = ${NUMPENDING}"
            NUMPENDING=$(kubectl get jobs --namespace $DOMAIN | awk '{print $3}' | grep 0 | wc -l | awk '{print $1}')
            sleep 3
            # if a job name was passed to this function, check the job status
            if [ $# -gt 0 ]; then
                COUNT=$((COUNT+1))
                if (( $COUNT % 5 == 0 )); then
                    # check for the pod status: e.g. Pods Statuses:  0 Running / 0 Succeeded / 6 Failed
                    NUMFAILED=$(kubectl describe jobs/$1 --namespace $DOMAIN | grep "Pods Statuses" | awk '{print $9}')
                    if [ $NUMFAILED -gt 0 ]; then
                        echo "'$NUMFAILED' jobs with name '$1' have failed so far in namespace '$DOMAIN'. After 6 failures we will exit"
                    fi
                    if [ $NUMFAILED -eq 6 ]; then
                        echo "'$NUMFAILED' jobs with name '$1' have failed in namespace '$DOMAIN'. We will exit"
                        return 1
                    fi

                fi
            fi
        done
    done
}

function confirmDeployments {
    log "Checking whether all deployments are ready"

    for TMPORG in $ORGS; do
        NUMPENDING=$(kubectl get deployments -n $TMPORG | awk '{print $5}' | grep 0 | wc -l | awk '{print $1}')
        while [ "${NUMPENDING}" != "0" ]; do
            echo "Waiting on pending deployments in namespace $TMPORG. Deployments pending = ${NUMPENDING}"
            NUMPENDING=$(kubectl get deployments -n $TMPORG | awk '{print $5}' | grep 0 | wc -l | awk '{print $1}')
            sleep 3
        done
    done
}

function confirmDeploymentsStopped {
    if [ $# -eq 0 ]; then
        echo "Usage: confirmDeploymentsStopped <deployment> <org - optional>"
        exit 1
    fi
    DEPLOY=$1
    if [ $# -eq 2 ]; then
        TMPORG=$2
        log "Checking whether pods have stopped for org '$TMPORG'"
        NUMPENDING=$(kubectl get po -n $TMPORG | grep $DEPLOY | awk '{print $5}' | wc -l | awk '{print $1}')
        while [ "${NUMPENDING}" != "0" ]; do
            echo "Waiting on deployments matching $DEPLOY in namespace $TMPORG to stop. Deployments pending = ${NUMPENDING}"
            NUMPENDING=$(kubectl get po -n $TMPORG | grep $DEPLOY | awk '{print $5}' | wc -l | awk '{print $1}')
            sleep 3
        done
    else
        log "Checking whether all pods have stopped"
        for TMPORG in $ORGS; do
            NUMPENDING=$(kubectl get po -n $TMPORG | grep $DEPLOY | awk '{print $5}' | wc -l | awk '{print $1}')
            while [ "${NUMPENDING}" != "0" ]; do
                echo "Waiting on deployments matching $DEPLOY in namespace $TMPORG to stop. Deployments pending = ${NUMPENDING}"
                NUMPENDING=$(kubectl get po -n $TMPORG | grep $DEPLOY | awk '{print $5}' | wc -l | awk '{print $1}')
                sleep 3
            done
        done
    fi
}

function whatsRunning {
    log "Check what is running"
    for TMPORG in $ORGS; do
        kubectl get deploy -n $TMPORG
        kubectl get po -n $TMPORG
    done
}
