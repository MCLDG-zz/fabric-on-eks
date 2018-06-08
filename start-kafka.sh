#!/usr/bin/env bash

set -e

SDIR=$(dirname "$0")
REPO=https://github.com/Yolean/kubernetes-kafka.git
REPODIR=kubernetes-kafka
FABRICREPO=fabric-on-eks

function main {
    echo "Beginning setup of Kafka for Hyperledger Fabric on Kubernetes ..."
    getRepo
    startStorageService
    startZookeeper
    startKafka
    testKafka
    whatsRunning
    echo "Setup of Kafka for Hyperledger Fabric on Kubernetes complete"
}

function getRepo {
    echo "Getting repo $REPO at $SDIR"
    cd $HOME
    if [ ! -d $REPODIR ]; then
        # clone repo, if it hasn't already been cloned
        git clone $REPO
    fi
    #override the 50kafka.yml in the repo
    cp fabric-on-eks/kafka/50kafka.yml kubernetes-kafka/kafka/50kafka.yml
}

function startStorageService {
    echo "Starting storage service required for Kafka"
    cd $HOME/$REPODIR
    kubectl apply -f configure/aws-storageclass-zookeeper-gp2.yml
    kubectl apply -f configure/aws-storageclass-broker-gp2.yml
}

function startZookeeper {
    echo "Starting Zookeeper service"
    cd $HOME/$REPODIR
    kubectl apply -f zookeeper/00namespace.yml
    kubectl apply -f zookeeper/10zookeeper-config.yml
    kubectl apply -f zookeeper/20pzoo-service.yml
    kubectl apply -f zookeeper/21zoo-service.yml
    kubectl apply -f zookeeper/30service.yml
    kubectl apply -f zookeeper/50pzoo.yml
    kubectl apply -f zookeeper/51zoo.yml
}

function startKafka {
    echo "Starting Kafka service"
    cd $HOME/$REPODIR
    kubectl apply -f kafka/10broker-config.yml
    kubectl apply -f kafka/20dns.yml
    kubectl apply -f kafka/30bootstrap-service.yml
    kubectl apply -f kafka/50kafka.yml
    #wait for Kafka to deploy. This could take a couple of minutes
    PODSPENDING=$(kubectl get pods --namespace=kafka | awk '{print $2}' | cut -d '/' -f1 | grep 0 | wc -l | awk '{print $1}')
    while [ "${PODSPENDING}" != "0" ]; do
        echo "Waiting on Kafka to deploy. Pods pending = ${PODSPENDING}"
        PODSPENDING=$(kubectl get pods --namespace=kafka | awk '{print $2}' | cut -d '/' -f1 | grep 0 | wc -l | awk '{print $1}')
        sleep 10
    done
}

function testKafka {
    echo "Testing the Kafka service"
    cd $HOME/$REPODIR
    kubectl apply -f kafka/test/
    #wait for the tests to complete. This could take a couple of minutes
    TESTSPENDING=$(kubectl get pods -l test-type=readiness --namespace=test-kafka | awk '{print $2}' | cut -d '/' -f1 | grep 0 | wc -l | awk '{print $1}')
    while [ "${TESTSPENDING}" != "0" ]; do
        echo "Waiting on Kafka test cases to complete. Tests pending = ${TESTSPENDING}"
        TESTSPENDING=$(kubectl get pods -l test-type=readiness --namespace=test-kafka | awk '{print $2}' | cut -d '/' -f1 | grep 0 | wc -l | awk '{print $1}')
        sleep 10
    done
}

function whatsRunning {
    echo "Check what is running"
    kubectl get all -n kafka
}

main

