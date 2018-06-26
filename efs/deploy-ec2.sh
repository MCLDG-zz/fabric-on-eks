#!/usr/bin/env bash
/*
 * Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this
 * software and associated documentation files (the "Software"), to deal in the Software
 * without restriction, including without limitation the rights to use, copy, modify,
 * merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
 * INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
 * PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#vpc details for cluster: eks-fabric
#AWSAccount=295744685835
#AWSAccountProfile=blog-tools
#region=us-west-2
#vpcid=vpc-d3a3afaa
#subneta=subnet-7e412107
#subnetb=subnet-5e189a15
#subnetc=subnet-ac5b22f6
#keypairname=eks-fabric-key
#volumename=dltefs
#mountpoint=opt/share

#vpc details for cluster: fabric-account-1
AWSAccount=570833937993
AWSAccountProfile=account1
region=us-east-1
vpcid=vpc-b8d5cac3
subneta=subnet-95fb9cdf
subnetb=subnet-88f92ad4
keypairname=eks-fabric-key-account1
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

#aws cloudformation deploy --stack-name ec2-cmd-client --template-file efs/ec2-for-efs.yaml \
#--capabilities CAPABILITY_NAMED_IAM \
#--parameter-overrides VPCId=$vpcid SubnetA=$subneta SubnetB=$subnetb SubnetC=$subnetc \
#KeyName=$keypairname VolumeName=$volumename MountPoint=$mountpoint \
#--profile $AWSAccountProfile --region $region

aws cloudformation deploy --stack-name ec2-cmd-client --template-file efs/ec2-for-efs-2AZ.yaml \
--capabilities CAPABILITY_NAMED_IAM \
--parameter-overrides VPCId=$vpcid SubnetA=$subneta SubnetB=$subnetb \
KeyName=$keypairname VolumeName=$volumename MountPoint=$mountpoint \
--profile $AWSAccountProfile --region $region
