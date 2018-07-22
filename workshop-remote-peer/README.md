# TODO

* Cloudformation script to create an S3 bucket that can be accessed by all workshop participants. Used for the crypto 
material, which will probably be a single S3 object .tar file.
* Improve the section on creating the Kubernetes cluster, especially the section on how to use the Heptio authenticator
and configure this for use on the bastion host
* S3 command for downloading the Fabric crypto material in step 6


# Hyperledger Fabric on Kubernetes

This workshop builds remote peers in other AWS accounts/regions, connects them to the orderer organisation, installs
the 'marbles' chaincode, and allows workshop participants to have fun swapping marbles. Each workshop participant will
run their own Fabric peer and see the Fabric state via a local Node.js application that connects to their own local peer, reading
their own local copy of the ledger.

The workshop gives participants the experience of building their own Kubernetes cluster before running a Fabric CA and
Fabric peers as pods in Kubernetes. Once the peer is running the participants will follow the steps to connect it to a
channel, install chaincode, test the channel connection, then run a Node.js application that connects to the peer 
and displays its state in a colourful UI.

## Workshop pre-requisites

You're going to interact with Fabric and the Kubernetes cluster from a bastion host that mounts an EFS drive. EFS is 
required to store the crypto material used by Fabric, and you'll need to copy the appropriate certs/keys to/from the EFS drive.
The pre-requisites are as follows:

* An AWS account where you can create a Kubernetes cluster (either your own Kubernetes cluster or EKS)
* Check that you can access the crypto material for the Fabric network from the S3 bucket: <S3 BUCKET HERE>



## Getting Started - common steps for POC & PROD options

We create the Kubernetes cluster first. This has the advantage that we can deploy the EC2 bastion into the same VPC
and mount EFS into the Kubernetes cluster. The disadvantage is configuring kubectl to connect to the Kubernetes
cluster via the config in ~/.kube/config - see Step 3. It's a small price to pay, so we'll stick with this approach for now. 
 
### Step 1: Create a Kubernetes cluster
You need a K8s cluster to start. You have two ways to create the cluster:

* Use KOPS to create a cluster: https://github.com/kubernetes/kops
* Depending on your region, you can use EKS: https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html

Regardless of which method you choose, make sure you create the worker nodes using a keypair that you have downloaded 
to your laptop so you can subsequently SSH into the K8s worker nodes.

Once your K8s cluster is created, SSH into each worker node and install EFS utils to enable the node to mount the EFS that 
stores the CA certs/keys.

```bash
sudo yum install -y amazon-efs-utils
```

### Step 2: Create an EC2 instance and EFS 
You will need an EC2 instance, which you will SSH into in order to start and test the Fabric network. You will 
also need an EFS volume for storing common scripts and public keys. The EFS volume must be accessible from
the Kubernetes cluster. Follow the steps below, which will create the EFS and make it available to the K8s cluster.

Check the parameters in efs/deploy-ec2.sh and update them as follows:
* The VPC and Subnet params should be those of your existing K8s cluster worker nodes
* Keyname is an AWS EC2 keypair you own, that you have previously saved to your laptop. You'll need this to access the EC2 
instance created by deploy-ec2.sh
* VolumeName is the name assigned to your EFS volume (there is no need to change this)
* Region should match the region where your K8s cluster is deployed

Once all the parameters are set, in a terminal window run ./efs/deploy-ec2.sh. Check the CFN console for completion. Once 
the CFN stack is complete, SSH to one of the EC2 instances using the keypair above. Either of the EC2 instances will work.
Once you've setup an EC2 instance, continue to SSH into the same instance.

The EFS should be mounted in /opt/share. After you've SSH'd, check this:

```bash
ls -l /opt/share
```

### Step 3: Prepare the EC2 instance for use
The EC2 instance you have created in Step 2 should already have kubectl installed. However, kubectl will have no
context and will not be pointing to a kubernetes cluster. We need to point it to the K8s cluster we created in Step 1.

The easiest method (though this should be improved) is to copy the contents of your own ~/.kube/config file from 
your Mac (or whichever device you used to create the Kubernetes cluster in Step 1). If you are expert on the format
of ~/.kube/config, you could copy only the sections relevant to your new K8s cluster.

To copy the kube config, do the following:
* On your Mac, copy the contents of ~/.kube/config
* On the EC2 instance created above, do 
```bash
mkdir /home/ec2-user/.kube
cd /home/ec2-user/.kube
vi config
```
* hit the letter 'i' and paste the contents you copied from your Mac. Shift-zz to save and exit vi

To check that this works execute:

```bash
kubectl get nodes
```

you should see the nodes belonging to your new K8s cluster:

```bash
$ kubectl get nodes
NAME                                           STATUS    ROLES     AGE       VERSION
ip-172-20-123-84.us-west-2.compute.internal    Ready     master    1h        v1.9.3
ip-172-20-124-192.us-west-2.compute.internal   Ready     node      1h        v1.9.3
ip-172-20-49-163.us-west-2.compute.internal    Ready     node      1h        v1.9.3
ip-172-20-58-206.us-west-2.compute.internal    Ready     master    1h        v1.9.3
ip-172-20-81-75.us-west-2.compute.internal     Ready     master    1h        v1.9.3
ip-172-20-88-121.us-west-2.compute.internal    Ready     node      1h        v1.9.3
```

If you are using EKS with the Heptio authenticator, you'll need to follow the instructions here
to get kubectl configured: https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html#eks-prereqs
You will also need to copy your .aws/config and .aws/credentials files 
to the EC2 instance. You'll only need the profile from these files that hosts the EKS workers.

### Step 4: Clone this repo to your EC2 instance
On the EC2 instance created in Step 2 above, in the home directory, clone this repo:

```bash
cd
git clone https://github.com/MCLDG/fabric-on-eks.git
```

### Step 5: Configure the EFS server URL
On the EC2 instance created in Step 2 above, in the newly cloned fabric-on-eks directory, update the script 
'gen-fabric.sh' so that the EFSSERVER variable contains the full URL of the EFS server created in 
Step 2. Do the following:

In the EFS console, obtain the full EFS URL for your new EFS. The URL should look something like this: 
EFSSERVER=fs-12a33ebb.efs.us-west-2.amazonaws.com

Then, back on the EC2 instance:

```bash
cd
cd fabric-on-eks
vi gen-fabric.sh
```

Look for the line starting with `EFSSERVER=`, and replace the URL with the one you copied from the EFS console. Using
vi you can simply move the cursor over the first character after `EFSSERVER=` and hit the 'x' key until the existing
URL is deleted. Then hit the 'i' key and ctrl-v paste the new URL. Shift-zz to save and exit vi. See, you're a vi expert
already.

### Step 6: Get the Fabric crypto information
Before creating your Fabric peer you'll need the certificate and key information for the organisation the peer belongs
to. The steps below are a quick and dirty way of obtaining this info - not recommended for production use, but it will
save us plenty of time fiddling around with keys, certificates and certificate authorities. 

A quick method of setting up a remote peer for an existing org involves copying the existing crypto material. We've made
this information available in an S3 bucket - you just need to download it and copy it to your EFS as follows:

* SSH into the EC2 instance you created in Step 2
* Download the crypto information:
```bash
S3 get blah blah
```
* Extract the crypto material:
```bash
cd /
rm -rf /opt/share
tar xvf ~/opt.tar 
ls -lR /opt/share
```
You should see something like this (though this is only a subset):

```bash
$ ls -lR /opt/share
/opt/share:
total 36
drwxrwxr-x 3 ec2-user ec2-user 6144 Jul 17 03:54 ica-org0
drwxrwxr-x 3 ec2-user ec2-user 6144 Jul 17 04:53 ica-org1
drwxrwxr-x 3 ec2-user ec2-user 6144 Jul 17 03:54 ica-org2
drwxrwxr-x 2 ec2-user ec2-user 6144 Jul 17 03:32 orderer
drwxrwxr-x 7 ec2-user ec2-user 6144 Jul 19 13:23 rca-data
drwxrwxr-x 3 ec2-user ec2-user 6144 Jul 17 03:34 rca-org0
drwxrwxr-x 3 ec2-user ec2-user 6144 Jul 17 03:34 rca-org1
drwxrwxr-x 3 ec2-user ec2-user 6144 Jul 17 03:34 rca-org2
drwxrwxr-x 2 ec2-user ec2-user 6144 Jul 19 12:45 rca-scripts

/opt/share/ica-org0:
total 124
-rw-r--r-- 1 root root   822 Jul 17 03:34 ca-cert.pem
-rw-r--r-- 1 root root  1600 Jul 17 03:34 ca-chain.pem
-rw-r--r-- 1 root root 15944 Jul 17 03:34 fabric-ca-server-config.yaml
-rw-r--r-- 1 root root 94208 Jul 17 03:54 fabric-ca-server.db
drwxr-xr-x 5 root root  6144 Jul 17 03:34 msp
-rw-r--r-- 1 root root   912 Jul 17 03:34 tls-cert.pem
.
.
.
```

### Step 7: Edit env.sh
We've reached the final step before we get our hands on Hyperledger Fabric. In this step we prepare the configuration
file used by the scripts that configure Fabric.

* SSH into the EC2 instance you created in Step 2
* Navigate to the `fabric-on-eks` repo
* You can choose any name for PEER_ORGS and PEER_DOMAINS, as long as it's one of the following:
    * org1
    * org2
* Edit the file `remote-peer/scripts/env-remote-peer.sh`. Update the following fields:
    * Set PEER_ORGS to one of the organisations in the Fabric network. Example: PEER_ORGS="org1"
    * Set PEER_DOMAINS to one of the domains in the Fabric network. Example: PEER_DOMAINS="org1"
    * Set PEER_PREFIX to any name you choose. This will become the name of your peer on the network. 
      Try to make this unique within the network. Example: PEER_PREFIX="michaelpeer"
* Don't change anything else.

### Step 8: Register Fabric user with the Fabric certificate authority
Before we can start our Fabric peer we must register it with the Fabric certificate authority (CA). This step
will start Fabric CA and register our peer:

```bash
./workshop-remote-peer/start-remote-fabric-setup.sh
```

Now let's investigate the results of the previous script. In the statements below, replace 'org5' with the org you
selected in step 7:

```bash
kubectl get po -n org5 
```

You should see something similar to this. So far we have started a root CA (rca), an intermediate CA (ica), and a pod that registers
peers identities (register-p).

```bash
NAME                              READY     STATUS    RESTARTS   AGE
ica-org5-589fdcbb86-xpdsn         1/1       Running   0          28s
rca-org5-d5bb98789-z488b          1/1       Running   0          1m
register-p-org5-6c9964c44-h69qg   1/1       Running   0          21s
```

Look at the logs for the register pod. Replace the pod name with your own pod name, the one returned by 'kubectl get po -n org5 ':

```bash
kubectl logs register-p-org5-6c9964c44-h69qg -n org5
```

You'll see something like this (edited for brevity), as the CA admin is enrolled with the intermediate CA, then the
peer user (in this case 'michaelpeer1-org5') is registered with the CA:

```bash
$ kubectl logs deploy/register-p-org5 -n org5
##### 2018-07-22 02:07:58 Registering peer for org org5 ...
##### 2018-07-22 02:07:58 Enrolling with ica-org5.org5 as bootstrap identity ...
2018/07/22 02:07:58 [DEBUG] Home directory: /root/cas/ica-org5.org5
2018/07/22 02:07:58 [INFO] Created a default configuration file at /root/cas/ica-org5.org5/fabric-ca-client-config.yaml
2018/07/22 02:07:58 [DEBUG] Client configuration settings: &{URL:https://ica-org5-admin:ica-org5-adminpw@ica-org5.org5:7054 MSPDir:msp TLS:{Enabled:true CertFiles:[/data/org5-ca-chain.pem] Client:{KeyFile: CertFile:}} Enrollment:{ Name: Secret:**** Profile: Label: CSR:<nil> CAName: AttrReqs:[]  } CSR:{CN:ica-org5-admin Names:[{C:US ST:North Carolina L: O:Hyperledger OU:Fabric SerialNumber:}] Hosts:[register-p-org5-6c9964c44-bfjp8] KeyRequest:<nil> CA:<nil> SerialNumber:} ID:{Name: Type:client Secret: MaxEnrollments:0 Affiliation:org1 Attributes:[] CAName:} Revoke:{Name: Serial: AKI: Reason: CAName: GenCRL:false} CAInfo:{CAName:} CAName: CSP:0xc4201aac90}
2018/07/22 02:07:58 [DEBUG] Entered runEnroll
.
.
.
2018/07/22 02:07:58 [DEBUG] Sending request
POST https://ica-org5.org5:7054/enroll
{"hosts":["register-p-org5-6c9964c44-bfjp8"],"certificate_request":"-----BEGIN CERTIFICATE REQUEST-----\nMIIBXzCCAQUCAQAwZjELMAkGA1UEBhMCVVMxFzAVBgNVBAgTDk5vcnRoIENhcm9s\naW5hMRQwEgYDVQQKEwtIeXBlcmxlZGdlcjEPMA0GA1UECxMGRmFicmljMRcwFQYD\nVQQDEw5pY2Etb3JnNS1hZG1pbjBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABEKN\nHyFYFebtDUEGoNaQk0vqLBLtXt4gB4CBGsJormllPWTiz8kZDi6hhBVwED2Qg4MF\nOrWYe4vMJ8LXXU/L2QKgPTA7BgkqhkiG9w0BCQ4xLjAsMCoGA1UdEQQjMCGCH3Jl\nZ2lzdGVyLXAtb3JnNS02Yzk5NjRjNDQtYmZqcDgwCgYIKoZIzj0EAwIDSAAwRQIh\nAPeoD6q+jZ2aIdky6k6PVMdvzrm6Fp/1FnSndlAKvjy7AiAFn/kir8Xc39MYvIsR\nQDQnf8gcpSOs3UZNYfy8f6bIOg==\n-----END CERTIFICATE REQUEST-----\n","profile":"","crl_override":"","label":"","NotBefore":"0001-01-01T00:00:00Z","NotAfter":"0001-01-01T00:00:00Z","CAName":""}
2018/07/22 02:07:58 [DEBUG] Received response
statusCode=201 (201 Created)
2018/07/22 02:07:58 [DEBUG] Response body result: map[Cert:LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUNYRENDQWdLZ0F3SUJBZ0lVVDhNdmczdVdnektET3JJNXZmRUFLeGh1WHFjd0NnWUlLb1pJemowRUF3SXcKWmpFTE1Ba0dBMVVFQmhNQ1ZWTXhGekFWQmdOVkJBZ1REazV2Y25Sb0lFTmhjbTlzYVc1aE1SUXdFZ1lEVlFRSwpFd3RJZVhCbGNteGxaR2RsY2pFUE1BMEdBMVVFQ3hNR1kyeHBaVzUwTVJjd0ZRWURWUVFERXc1eVkyRXRiM0puCk5TMWhaRzFwYmpBZUZ3MHhPREEzTWpJd01qQXpNREJhRncweE9UQTNNakl3TWpBNE1EQmFNR1l4Q3pBSkJnTlYKQkFZVEFsVlRNUmN3RlFZRFZRUUlFdzVPYjNKMGFDQkRZWEp2YkdsdVlURVVNQklHQTFVRUNoTUxTSGx3WlhKcwpaV1JuWlhJeER6QU5CZ05WQkFzVEJtTnNhV1Z1ZERFWE1CVUdBMVVFQXhNT2FXTmhMVzl5WnpVdFlXUnRhVzR3CldUQVRCZ2NxaGtqT1BRSUJCZ2dxaGtqT1BRTUJCd05DQUFSQ2pSOGhXQlhtN1ExQkJxRFdrSk5MNml3UzdWN2UKSUFlQWdSckNhSzVwWlQxazRzL0pHUTR1b1lRVmNCQTlrSU9EQlRxMW1IdUx6Q2ZDMTExUHk5a0NvNEdOTUlHSwpNQTRHQTFVZER3RUIvd1FFQXdJSGdEQU1CZ05WSFJNQkFmOEVBakFBTUIwR0ExVWREZ1FXQkJSdENJK25hNmdoCnRKdjVNU1ViQm1KdkVjSmxGREFmQmdOVkhTTUVHREFXZ0JUczQ4bzhGN2RBLzl6ZFdNUGpsY05oQTRMNlFEQXEKQmdOVkhSRUVJekFoZ2g5eVpXZHBjM1JsY2kxd0xXOXlaelV0Tm1NNU9UWTBZelEwTFdKbWFuQTRNQW9HQ0NxRwpTTTQ5QkFNQ0EwZ0FNRVVDSVFDZnNTWGNQUHRaQjZpK1l5Nkc5WmVDVW4xcy9tUFN2Q1pJelVaV3ViU3Fid0lnClJHaE80TXFiay82Tkl3N0ROZUREVkhTb1F6WFkrejkyU1pJUnZIZGwxUmM9Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K ServerInfo:map[CAName:ica-org5.org5 CAChain:LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUNNekNDQWRtZ0F3SUJBZ0lVTDlhUDhPM283V0ZjUzM3cm9WNXJLcnBLRXBNd0NnWUlLb1pJemowRUF3SXcKWlRFTE1Ba0dBMVVFQmhNQ1ZWTXhGekFWQmdOVkJBZ1REazV2Y25Sb0lFTmhjbTlzYVc1aE1SUXdFZ1lEVlFRSwpFd3RJZVhCbGNteGxaR2RsY2pFUE1BMEdBMVVFQ3hNR1JtRmljbWxqTVJZd0ZBWURWUVFERXcxeVkyRXRiM0puCk5TNXZjbWMxTUI0WERURTRNRGN5TWpBeE1EWXdNRm9YRFRJek1EY3lNVEF4TVRFd01Gb3daakVMTUFrR0ExVUUKQmhNQ1ZWTXhGekFWQmdOVkJBZ1REazV2Y25Sb0lFTmhjbTlzYVc1aE1SUXdFZ1lEVlFRS0V3dEllWEJsY214bApaR2RsY2pFUE1BMEdBMVVFQ3hNR1kyeHBaVzUwTVJjd0ZRWURWUVFERXc1eVkyRXRiM0puTlMxaFpHMXBiakJaCk1CTUdCeXFHU000OUFnRUdDQ3FHU000OUF3RUhBMElBQkpZSTUyem1WNmpvejJ5c2IxRnZpN2NmNU5vdUhvTnIKK0orMUtnUFFwbXlnMGJMVCtTZldzVXh2Tml1eS9rRHNUOVQ0Kzl4K0l6Zk1Wc1A3U2JJbkIzdWpaakJrTUE0RwpBMVVkRHdFQi93UUVBd0lCQmpBU0JnTlZIUk1CQWY4RUNEQUdBUUgvQWdFQU1CMEdBMVVkRGdRV0JCVHM0OG84CkY3ZEEvOXpkV01QamxjTmhBNEw2UURBZkJnTlZIU01FR0RBV2dCVHNnNXB1bUx0UzV5WE1YSHExdHU0TDFhYWkKNGpBS0JnZ3Foa2pPUFFRREFnTklBREJGQWlFQSs1eGUrTTl3aXp6cVR0RHhteisxSElnR0VpVTZBQVhBenI3LwpUOGsvK3JVQ0lHeFZaUkRmV2RLQVVvcHRUNjNLajFQc2IxZUlhNHpKSGZhbVVXdkJSNERRCi0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0KLS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUNFVENDQWJlZ0F3SUJBZ0lVZVVxMWZyMW11dUpuSzgrZ21PUjh3czRLNHV3d0NnWUlLb1pJemowRUF3SXcKWlRFTE1Ba0dBMVVFQmhNQ1ZWTXhGekFWQmdOVkJBZ1REazV2Y25Sb0lFTmhjbTlzYVc1aE1SUXdFZ1lEVlFRSwpFd3RJZVhCbGNteGxaR2RsY2pFUE1BMEdBMVVFQ3hNR1JtRmljbWxqTVJZd0ZBWURWUVFERXcxeVkyRXRiM0puCk5TNXZjbWMxTUI0WERURTRNRGN5TWpBeE1EVXdNRm9YRFRNek1EY3hPREF4TURVd01Gb3daVEVMTUFrR0ExVUUKQmhNQ1ZWTXhGekFWQmdOVkJBZ1REazV2Y25Sb0lFTmhjbTlzYVc1aE1SUXdFZ1lEVlFRS0V3dEllWEJsY214bApaR2RsY2pFUE1BMEdBMVVFQ3hNR1JtRmljbWxqTVJZd0ZBWURWUVFERXcxeVkyRXRiM0puTlM1dmNtYzFNRmt3CkV3WUhLb1pJemowQ0FRWUlLb1pJemowREFRY0RRZ0FFd1A2Q0JaQ2V5bDIyMGdIdjN2bndMOEVpR1Z1NGNRdGEKZDNTcjJuems0TGMwSEZWeG8wdXplbG9QR05uaUZ1blFjZ3FwcnkvTG5lVDJsYmZtTGcyK0c2TkZNRU13RGdZRApWUjBQQVFIL0JBUURBZ0VHTUJJR0ExVWRFd0VCL3dRSU1BWUJBZjhDQVFFd0hRWURWUjBPQkJZRUZPeURtbTZZCnUxTG5KY3hjZXJXMjdndlZwcUxpTUFvR0NDcUdTTTQ5QkFNQ0EwZ0FNRVVDSVFEZ1h5MHN6elJWT2JTbDNOTmsKS2xFN2hQR1BSR2FUeDMwTFdEUnBWNlpOUUFJZ2FoWC84azNyTGd6T1U4OWRhVFFDTVpQaGFkVzBBOEQ3cXh6YgoxRUh4bEVzPQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg== Version:]]
2018/07/22 02:07:58 [DEBUG] newEnrollmentResponse ica-org5-admin
2018/07/22 02:07:58 [INFO] Stored client certificate at /root/cas/ica-org5.org5/msp/signcerts/cert.pem
2018/07/22 02:07:58 [INFO] Stored root CA certificate at /root/cas/ica-org5.org5/msp/cacerts/ica-org5-org5-7054.pem
2018/07/22 02:07:58 [INFO] Stored intermediate CA certificates at /root/cas/ica-org5.org5/msp/intermediatecerts/ica-org5-org5-7054.pem
##### 2018-07-22 02:07:58 Registering michaelpeer1-org5 with ica-org5.org5
2018/07/22 02:07:58 [DEBUG] Home directory: /root/cas/ica-org5.org5
.
. 
.
2018/07/22 02:07:58 [DEBUG] Sending request
POST https://ica-org5.org5:7054/register
{"id":"michaelpeer1-org5","type":"peer","secret":"michaelpeer1-org5pw","affiliation":"org1"}
2018/07/22 02:07:59 [DEBUG] Received response
statusCode=201 (201 Created)
2018/07/22 02:07:59 [DEBUG] Response body result: map[secret:michaelpeer1-org5pw]
2018/07/22 02:07:59 [DEBUG] The register request completed successfully
Password: michaelpeer1-org5pw
##### 2018-07-22 02:07:59 Finished registering peer for org org5
```

### Step 9:
We are now ready to start the new peer. The peer runs as a pod in Kubernetes. Let's take a look at the pod spec before
we deploy it. Replace 'michaelpeer1' with the name of your peer, and replace 'org5' with the org you selected. If you 
are unsure, you can simply do 'ls k8s' to view the yaml files that were generated based on your selections, and find
the file start starts with 'fabric-deployment-remote-peer-'.

```bash
more k8s/fabric-deployment-remote-peer-michaelpeer1-org5.yaml
```

There are a few things of interest in the pod yaml file:

* The pod specifies 2 containers: couchdb, a key-value store which stores the Fabric world state, and the peer itself
* The peer is bootstrapped using a script, which you can view by opening 'scripts/start-peer.sh'
* The peer is exposed using a Kubernetes service

So let's deploy the peer and check the logs:

```bash
kubectl apply -f k8s/fabric-deployment-remote-peer-michaelpeer1-org5.yaml

```

SSH into the EC2 instance you created in Step 2, navigate to the `fabric-on-eks` 
repo and run:

```bash
./remote-peer/start-remote-peer.sh
```

This will do the following:

* Create a merged copy of env.sh on the EFS drive (i.e. in /opt/share/rca-scripts), which includes the selections you
made above (e.g. PEER_PREFIX)
* Generate a kubernetes deployment YAML for the remote peer
* Start a local certificate authority (CA). You'll need this to generate a new user for your peer
* Register your new peer with the CA
* Start the new peer

The peer will start, but will not be joined to any channels. At this point the peer has little use as it does not 
maintain any ledger state. To start building a ledger on the peer we need to join a channel.

### Join the peer to a channel
I've created a Kubernetes deployment YAML that will deploy a POD to execute a script, `test-fabric-marbles`, that will
join the peer created above to a channel (the channel name is in env.sh), install the marbles demo chaincode, and 
execute a couple of test transactions. Run the following:

```bash
kubectl apply -f k8s/fabric-deployment-test-fabric-marbles.yaml
```

This will connect the new peer to the channel. You should then check the peer logs to ensure
all the TX are being sent to the new peer. If there are existing blocks on the channel you should see them
replicating to the new peer. Look for messages in the log file such as `Channel [mychannel]: Committing block [14385] to storage`.
