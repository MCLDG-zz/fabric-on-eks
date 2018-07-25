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

SDIR=$(dirname "$0")
DATA=/opt/share
SCRIPTS=$DATA/rca-scripts
source $SCRIPTS/env.sh
source $SDIR/utilities.sh
REPO=fabric-on-eks
K8STEMPLATES=k8s-templates
K8SYAML=k8s
EFSSERVER=fs-99a736d1.efs.us-east-1.amazonaws.com
FABRICORGS=""
DATA=/opt/share

# Beginning port numbers
# Original settings.
# I need a better way of ensuring unique port numbers, as orgs are added and deleted
#rcaport=30300
#icaport=30320
#ordererport=30340
#peerport=30450

rcaport=30700
icaport=30720
ordererport=30740
peerport=30750

#Ports should look something like this:
#org0    rca     7054->30300
#        ica     7054->30320
#        orderer       30340
#
#org1    rca     7054->30400
#        ica     7054->30420
#        orderer       30440
#        peer1         30451,30452
#        peer2         30453,30454
#
#org2    rca     7054->30500
#        ica     7054->30520
#        orderer       30540
#        peer1         30551,30552
#        peer2         30553,30554


function main {
    log "Beginning creation of Hyperledger Fabric Kubernetes YAML files..."
    cd $HOME/$REPO
    rm -rf $K8SYAML
    mkdir -p $K8SYAML
    file=${DATA}/rca-data/updateorg
    if [ -f "$file" ]; then
       NEW_ORG=$(cat $file)
       echo "File '$file' exists - gen_fabric.sh identifies a new org '$NEW_ORG', and will generate appropriate K8s YAML files"
    fi
    genFabricOrgs
    genNamespaces
    genPVC
    genRCA
    genICA
    genRegisterOrg
    genRegisterOrderer
    genRegisterPeers
    genChannelArtifacts
    genOrderer
    genPeers
    genRemotePeers
    genPeerJoinChannel
    genFabricTest
    genFabricTestMarbles
    genInstallMarblesCC
    genLoadFabric
    genLoadFabricMarbles
    genAddOrg
    genSignAddOrg
    genUpdateConfAddOrg
    genJoinAddOrg
    genInstallCCAddOrg
    genUpgradeCCAddOrg
    genTestCCAddOrg
    genDeleteOrg
    log "Creation of Hyperledger Fabric Kubernetes YAML files complete"
}

function genFabricOrgs {
    log "Generating list of Fabric Orgs"
    for ORG in $ORGS; do
        getDomain $ORG
        FABRICORGS+=$ORG
        FABRICORGS+="."
        FABRICORGS+=$DOMAIN
        FABRICORGS+=" "
    done
    log "Fabric Orgs are $FABRICORGS"
}

function genNamespaces {
    log "Generating K8s namespace YAML files"
    cd $HOME/$REPO
    for DOMAIN in $DOMAINS; do
        sed -e "s/%DOMAIN%/${DOMAIN}/g" ${K8STEMPLATES}/fabric-namespace.yaml > ${K8SYAML}/fabric-namespace-$DOMAIN.yaml
    done
}

function genPVC {
    log "Generating K8s PVC YAML files"
    cd $HOME/$REPO
    for ORG in $ORGS; do
        getDomain $ORG
        sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" -e "s/%EFSSERVER%/${EFSSERVER}/g" ${K8STEMPLATES}/fabric-pvc-rca-scripts.yaml > ${K8SYAML}/fabric-pvc-rca-scripts-$ORG.yaml
        sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" -e "s/%EFSSERVER%/${EFSSERVER}/g" ${K8STEMPLATES}/fabric-pvc-rca-data.yaml > ${K8SYAML}/fabric-pvc-rca-data-$ORG.yaml
        sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" -e "s/%EFSSERVER%/${EFSSERVER}/g" ${K8STEMPLATES}/fabric-pvc-rca.yaml > ${K8SYAML}/fabric-pvc-rca-$ORG.yaml
        sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" -e "s/%EFSSERVER%/${EFSSERVER}/g" ${K8STEMPLATES}/fabric-pvc-ica.yaml > ${K8SYAML}/fabric-pvc-ica-$ORG.yaml
    done
    for ORG in $ORDERER_ORGS; do
        getDomain $ORG
        sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" -e "s/%EFSSERVER%/${EFSSERVER}/g" ${K8STEMPLATES}/fabric-pvc-orderer.yaml > ${K8SYAML}/fabric-pvc-orderer-$ORG.yaml
    done
}

function genRCA {
    log "Generating RCA K8s YAML files"
    for ORG in $ORGS; do
        getDomain $ORG
        sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" -e "s/%FABRICORGS%/${FABRICORGS}/g" -e "s/%PORT%/${rcaport}/g" ${K8STEMPLATES}/fabric-deployment-rca.yaml > ${K8SYAML}/fabric-deployment-rca-$ORG.yaml
        rcaport=$((rcaport+100))
    done
}

function genICA {
    log "Generating ICA K8s YAML files"
    for ORG in $ORGS; do
        getDomain $ORG
        sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" -e "s/%FABRICORGS%/${FABRICORGS}/g" -e "s/%PORT%/${icaport}/g" ${K8STEMPLATES}/fabric-deployment-ica.yaml > ${K8SYAML}/fabric-deployment-ica-$ORG.yaml
        sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" ${K8STEMPLATES}/fabric-nlb-ca.yaml > ${K8SYAML}/fabric-nlb-ca-$ORG.yaml
        sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" ${K8STEMPLATES}/fabric-elb-ca.yaml > ${K8SYAML}/fabric-elb-ca-$ORG.yaml
        icaport=$((icaport+100))
    done
}

function genRegisterOrg {
    log "Generating Register Org K8s YAML files"
    for ORG in $ORGS; do
        getDomain $ORG
        sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" ${K8STEMPLATES}/fabric-deployment-register-org.yaml > ${K8SYAML}/fabric-deployment-register-org-$ORG.yaml
    done
}

function genRegisterOrderer {
    log "Generating Register Orderer K8s YAML files"
    for ORG in $ORDERER_ORGS; do
        getDomain $ORG
        sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" ${K8STEMPLATES}/fabric-deployment-register-orderer.yaml > ${K8SYAML}/fabric-deployment-register-orderer-$ORG.yaml
    done
}

function genRegisterPeers {
    log "Generating Register Peer K8s YAML files"
    for ORG in $PEER_ORGS; do
        getDomain $ORG
        sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" ${K8STEMPLATES}/fabric-deployment-register-peer.yaml > ${K8SYAML}/fabric-deployment-register-peer-$ORG.yaml
    done
}

function genAddOrg {
    log "Generating Add Org Peer K8s YAML files"
    getAdminOrg
    getDomain $ADMINORG
    sed -e "s/%ORG%/${ADMINORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" ${K8STEMPLATES}/fabric-job-addorg-setup.yaml > ${K8SYAML}/fabric-job-addorg-setup-$ADMINORG.yaml
}

function genSignAddOrg {
    log "Generating CLI to sign channel updates K8s YAML files"
    for ORG in $PEER_ORGS; do
        getDomain $ORG
        sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" ${K8STEMPLATES}/fabric-job-signconf.yaml > ${K8SYAML}/fabric-job-signconf-$ORG.yaml
    done
}

function genUpdateConfAddOrg {
    log "Generating CLI to update config for channel updates Peer K8s YAML files"
    getAdminOrg
    getDomain $ADMINORG
    sed -e "s/%ORG%/${ADMINORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" ${K8STEMPLATES}/fabric-job-updateconf.yaml > ${K8SYAML}/fabric-job-updateconf-$ADMINORG.yaml
}

function genJoinAddOrg {
    log "Generating CLI to join org to channel - new org is: '$NEW_ORG'"
    if [ -z ${NEW_ORG+x} ]; then
        log "No new org is defined"
    else
        log "Generating Joining 3rd Org Peer K8s YAML files"
        export ORG=$NEW_ORG
        getDomain $ORG
        sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" ${K8STEMPLATES}/fabric-job-addorg-join.yaml > ${K8SYAML}/fabric-job-addorg-join-$ORG.yaml
    fi
}

function genInstallCCAddOrg {
    log "Generating CLI to install CC Peer K8s YAML files"
    for ORG in $PEER_ORGS; do
        getDomain $ORG
        sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" ${K8STEMPLATES}/fabric-job-installcc.yaml > ${K8SYAML}/fabric-job-installcc-$ORG.yaml
    done
}

function genTestCCAddOrg {
    log "Generating CLI to test CC Peer K8s YAML files"
    for ORG in $PEER_ORGS; do
        getDomain $ORG
        sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" ${K8STEMPLATES}/fabric-job-testcc.yaml > ${K8SYAML}/fabric-job-testcc-$ORG.yaml
    done
}

function genUpgradeCCAddOrg {
    log "Generating CLI to upgrade CC Peer K8s YAML files"
    getAdminOrg
    getDomain $ADMINORG
    sed -e "s/%ORG%/${ADMINORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" ${K8STEMPLATES}/fabric-job-upgradecc.yaml > ${K8SYAML}/fabric-job-upgradecc-$ADMINORG.yaml
}

function genDeleteOrg {
    getAdminOrg
    getDomain $ADMINORG
    sed -e "s/%ORG%/${ADMINORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" ${K8STEMPLATES}/fabric-job-delete-org.yaml > ${K8SYAML}/fabric-job-delete-org-$ADMINORG.yaml
}

function genChannelArtifacts {
    log "Generating Channel Artifacts Setup K8s YAML files"
    #get the first orderer org. Setup only needs to run once, against the orderer org
    orgsarr=($ORDERER_ORGS)
    ORG=${orgsarr[0]}
    getDomain $ORG
    sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" ${K8STEMPLATES}/fabric-deployment-channel-artifacts.yaml > ${K8SYAML}/fabric-deployment-channel-artifacts.yaml
}

function genOrderer {
    log "Generating Orderer K8s YAML files"
    for ORG in $ORDERER_ORGS; do
        getDomain $ORG
        local COUNT=1
        while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
            sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" -e "s/%NUM%/${COUNT}/g" -e "s/%PORT%/${ordererport}/g" ${K8STEMPLATES}/fabric-deployment-orderer.yaml > ${K8SYAML}/fabric-deployment-orderer$COUNT-$ORG.yaml
            sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" -e "s/%NUM%/${COUNT}/g" ${K8STEMPLATES}/fabric-nlb-orderer.yaml > ${K8SYAML}/fabric-nlb-orderer$COUNT-$ORG.yaml
            COUNT=$((COUNT+1))
            ordererport=$((ordererport+1))
        done
        ordererport=$((ordererport+100))
    done
}

function genPeers {
    log "Generating Peer K8s YAML files"
    for ORG in $PEER_ORGS; do
        getDomain $ORG
        local COUNT=1
        #the first peer of an org defaults to the anchor peer
        sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" -e "s/%NUM%/${COUNT}/g" ${K8STEMPLATES}/fabric-nlb-anchor-peer.yaml > ${K8SYAML}/fabric-nlb-anchor-peer$COUNT-$ORG.yaml
        PORTCHAIN=$peerport
        while [[ "$COUNT" -le $NUM_PEERS ]]; do
            PORTCHAIN=$((PORTCHAIN+2))
            PORTEND=$((PORTCHAIN-1))
            sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" -e "s/%NUM%/${COUNT}/g" -e "s/%PORTEND%/${PORTEND}/g" -e "s/%PORTCHAIN%/${PORTCHAIN}/g" ${K8STEMPLATES}/fabric-deployment-peer.yaml > ${K8SYAML}/fabric-deployment-peer$COUNT-$ORG.yaml
            COUNT=$((COUNT+1))
        done
        peerport=$((peerport+100))
   done
}


function genRemotePeers {
    peerport=30750
    log "Generating Remote Peer K8s YAML files"
    for ORG in $PEER_ORGS; do
        getDomain $ORG
        local COUNT=1
        PORTCHAIN=$peerport
        while [[ "$COUNT" -le $NUM_PEERS ]]; do
            PORTCHAIN=$((PORTCHAIN+2))
            PORTEND=$((PORTCHAIN-1))
            sed -e "s/%PEER_PREFIX%/${PEER_PREFIX}/g" -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" -e "s/%NUM%/${COUNT}/g" -e "s/%PORTEND%/${PORTEND}/g" -e "s/%PORTCHAIN%/${PORTCHAIN}/g" remote-peer/k8s/fabric-deployment-remote-peer.yaml > ${K8SYAML}/fabric-deployment-remote-peer-${PEER_PREFIX}${COUNT}-$ORG.yaml
            sed -e "s/%PEER_PREFIX%/${PEER_PREFIX}/g" -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" -e "s/%NUM%/${COUNT}/g" remote-peer/k8s/fabric-nlb-remote-peer.yaml > ${K8SYAML}/fabric-nlb-remote-peer-${PEER_PREFIX}${COUNT}-$ORG.yaml
            COUNT=$((COUNT+1))
        done
        peerport=$((peerport+100))
   done
}

function genPeerJoinChannel {
    log "Generating Peer Joins Channel K8s YAML files"
    getAdminOrg
    getDomain $ADMINORG
    export NUM=1
    sed -e "s/%ORG%/${ADMINORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" -e "s/%NUM%/${NUM}/g" ${K8STEMPLATES}/fabric-deployment-peer-join-channel.yaml > ${K8SYAML}/fabric-deployment-peer-join-channel$COUNT-$ADMINORG.yaml
}

function genFabricTest {
    log "Generating Fabric Test K8s YAML files"
    #get the first peer org. Setup only needs to run once, against the peer org
    getAdminOrg
    getDomain $ADMINORG
    sed -e "s/%ORG%/${ADMINORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" ${K8STEMPLATES}/fabric-deployment-test-fabric-abac.yaml > ${K8SYAML}/fabric-deployment-test-fabric-abac.yaml
}

function genFabricTestMarbles {
    log "Generating Fabric Test Marbles K8s YAML files"
    #get the first peer org. Setup only needs to run once, against the peer org
    getAdminOrg
    getDomain $ADMINORG
    sed -e "s/%ORG%/${ADMINORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" ${K8STEMPLATES}/fabric-deployment-test-fabric-marbles.yaml > ${K8SYAML}/fabric-deployment-test-fabric-marbles.yaml
}

function genInstallMarblesCC {
    log "Generating Install Marbles CC K8s YAML files"
    #get the first peer org. Setup only needs to run once, against the peer org
    getAdminOrg
    getDomain $ADMINORG
    sed -e "s/%ORG%/${ADMINORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" ${K8STEMPLATES}/fabric-deployment-install-marbles-cc.yaml > ${K8SYAML}/fabric-deployment-install-marbles-cc.yaml
}

function genLoadFabric {
    log "Generating Load Fabric K8s YAML files"
    for ORG in $PEER_ORGS; do
        getDomain $ORG
        sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" ${K8STEMPLATES}/fabric-deployment-load-fabric.yaml > ${K8SYAML}/fabric-deployment-load-fabric-$ORG.yaml
   done
}

function genLoadFabricMarbles {
    log "Generating Load Fabric Marbles K8s YAML files"
    for ORG in $PEER_ORGS; do
        getDomain $ORG
        sed -e "s/%ORG%/${ORG}/g" -e "s/%DOMAIN%/${DOMAIN}/g" ${K8STEMPLATES}/fabric-deployment-load-fabric-marbles.yaml > ${K8SYAML}/fabric-deployment-load-fabric-marbles-$ORG.yaml
   done
}

main

