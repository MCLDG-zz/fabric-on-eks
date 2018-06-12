#!/usr/bin/env bash

SDIR=$(dirname "$0")
REPO=https://github.com/Yolean/kubernetes-kafka.git
REPODIR=kubernetes-kafka
FABRICREPO=fabric-on-eks

function main {
    echo "Stopping Kafka for Hyperledger Fabric on Kubernetes ..."
    stopTestKafka
    stopKafka
    stopZookeeper
    stopStorageService
    whatsRunning
    echo "Stopping of Kafka for Hyperledger Fabric on Kubernetes complete"
}

function stopStorageService {
    echo "Stopping the storage service required for Kafka"
    cd $HOME/$REPODIR
    kubectl delete -f configure/aws-storageclass-broker-gp2.yml
    kubectl delete -f configure/aws-storageclass-zookeeper-gp2.yml
    kubectl delete pvc --all -n kafka
}

function stopZookeeper {
    echo "Stopping the Zookeeper service"
    cd $HOME/$REPODIR
    kubectl delete -f zookeeper/
    #wait for Kafka to stop
    PODSPENDING=$(kubectl get pods --namespace=kafka)
    while [ "${PODSPENDING}" != "" ]; do
        echo "Waiting on Kafka to stop"
        PODSPENDING=$(kubectl get pods --namespace=kafka)
        sleep 10
    done
}

function stopKafka {
    echo "Stopping the Kafka service"
    cd $HOME/$REPODIR
    kubectl delete -f $HOME/$FABRICREPO/kafka/
    kubectl delete -f kafka/
}

function stopTestKafka {
    echo "Stopping the Kafka test service"
    cd $HOME/$REPODIR
    kubectl delete -f kafka/test/
    #wait for the tests to stop
    TESTSPENDING=$(kubectl get pods -l test-type=readiness --namespace=test-kafka)
    while [ "${TESTSPENDING}" != "" ]; do
        echo "Waiting on Kafka test cases to stop"
        TESTSPENDING=$(kubectl get pods -l test-type=readiness --namespace=test-kafka)
        sleep 10
    done
}

function whatsRunning {
    echo "Check what is running"
    kubectl get all -n kafka
}

main

