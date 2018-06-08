#!/usr/bin/env bash

#vpc details for cluster: mcdgk8s
AWSAccount=295744685835
AWSAccountProfile=blog-tools
region=us-west-2
vpcid=vpc-d3a3afaa
subneta=subnet-7e412107
subnetb=subnet-5e189a15
subnetc=subnet-ac5b22f6
keypairname=eks-fabric-key
volumename=dltefs
mountpoint=opt/share

#vpc details for cluster: mcdg2k8s
#AWSAccount=295744685835
#AWSAccountProfile=blog-tools
#region=us-east-2
#vpcid=vpc-2725a74f
#subneta=subnet-067eff6e
#subnetb=subnet-d3bc44a9
#subnetc=subnet-2e291e63
#keypairname=dlt-blockchain-key
#volumename=dltefs2
#mountpoint=opt/share

#vpc details for cluster: fabrick8s
#AWSAccount=709854728547
#AWSAccountProfile=acn-cpa
#region=us-east-1
#keypairname=atc-fabric-key
#volumename=dltefs
#vpcid=vpc-a0f5d1db
#subneta=subnet-8dc401ea
#subnetb=subnet-68c33246
#subnetc=subnet-71873c3b
#mountpoint=opt/share

aws cloudformation deploy --stack-name ec2-cmd-client --template-file efs/ec2-for-efs.yaml \
--capabilities CAPABILITY_NAMED_IAM \
--parameter-overrides VPCId=$vpcid SubnetA=$subneta SubnetB=$subnetb SubnetC=$subnetc \
KeyName=$keypairname VolumeName=$volumename MountPoint=$mountpoint \
--profile $AWSAccountProfile --region $region

