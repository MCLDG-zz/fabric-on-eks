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
You will need an EC2 bastion, which you will use to start and test the Fabric network. You will also need an EFS volume for 
storing common scripts and the certificates used by Fabric. The EFS volume must be accessible from both the EC2 bastion and 
the worker nodes in the Kubernetes cluster. Follow the steps below, which will create the EFS and make it available to the K8s cluster.

In the repo directory, check the parameters in efs/deploy-ec2.sh and update them as follows:
* The VPC and Subnet should be those of your existing K8s cluster worker nodes
* Keyname is an AWS EC2 keypair you own, that you have previously saved to your laptop. You'll need this to access the EC2 bastion created by deploy-ec2.sh
* VolumeName is the name assigned to your EFS volume (there is no need to change this)
* Region should match the region where your K8s cluster is deployed

Once all the parameters are set, in a terminal window, run 

```bash
./efs/deploy-ec2.sh 
```

Check the CFN console for completion. Once the CFN stack is complete, SSH to one of the EC2 bastion instances using the keypair 
above. Either of the EC2 instances will work. Once you've setup an EC2 instance, continue to SSH into the same EC2 bastion instance.

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
URL is deleted. Then hit the 'i' key and ctrl-v to paste the new URL. Hit escale, then Shift-zz to save and exit vi. 
See, you're a vi expert already.

### Step 6: Get the Fabric crypto information
Before creating your Fabric peer you'll need the certificate and key information for the organisation the peer belongs
to. The steps below are a quick and dirty way of obtaining this info - not recommended for production use, but it will
save us plenty of time fiddling around with keys, certificates and certificate authorities. 

A quick method of setting up a remote peer for an existing org involves copying the existing crypto material. We've made
this information available in an S3 bucket - you just need to download it and copy it to your EFS as follows:

* SSH into the EC2 instance you created in Step 2
* Download the crypto information:
```bash
cd
TBC - S3 get blah blah
```
* Extract the crypto material:
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

### Step 8: Register Fabric identities with the Fabric certificate authority
Before we can start our Fabric peer we must register it with the Fabric certificate authority (CA). This step
will start Fabric CA and register our peer:

```bash
./workshop-remote-peer/start-remote-fabric-setup.sh
```

Now let's investigate the results of the previous script. In the statements below, replace 'org5' with the org you
selected in step 7:

```bash
kubectl get po -n org1 
```

You should see something similar to this. So far we have started a root CA (rca), an intermediate CA (ica), and a pod that registers
peers identities (register-p).

```bash
$ kubectl get po -n org1
NAME                               READY     STATUS    RESTARTS   AGE
ica-org1-5694787654-g5j9l          1/1       Running   0          45s
rca-org1-6c769cc569-5cfqb          1/1       Running   0          1m
register-p-org1-66bd5688b4-fhzmh   1/1       Running   0          28s
```

Look at the logs for the register pod. Replace the pod name with your own pod name, the one returned by 'kubectl get po -n org5 ':

```bash
kubectl logs register-p-org1-66bd5688b4-fhzmh -n org1
```

You'll see something like this (edited for brevity), as the CA admin is enrolled with the intermediate CA, then the
peer user (in this case 'michaelpeer1-org5') is registered with the CA:

```bash
$ kubectl logs register-p-org1-66bd5688b4-fhzmh -n org1
##### 2018-07-22 02:52:31 Registering peer for org org1 ...
##### 2018-07-22 02:52:31 Enrolling with ica-org1.org1 as bootstrap identity ...
2018/07/22 02:52:31 [DEBUG] Home directory: /root/cas/ica-org1.org1
2018/07/22 02:52:31 [INFO] Created a default configuration file at /root/cas/ica-org1.org1/fabric-ca-client-config.yaml
2018/07/22 02:52:31 [DEBUG] Client configuration settings: &{URL:https://ica-org1-admin:ica-org1-adminpw@ica-org1.org1:7054 MSPDir:msp TLS:{Enabled:true CertFiles:[/data/org1-ca-chain.pem] Client:{KeyFile: CertFile:}} Enrollment:{ Name: Secret:**** Profile: Label: CSR:<nil> CAName: AttrReqs:[]  } CSR:{CN:ica-org1-admin Names:[{C:US ST:North Carolina L: O:Hyperledger OU:Fabric SerialNumber:}] Hosts:[register-p-org1-66bd5688b4-fhzmh] KeyRequest:<nil> CA:<nil> SerialNumber:} ID:{Name: Type:client Secret: MaxEnrollments:0 Affiliation:org1 Attributes:[] CAName:} Revoke:{Name: Serial: AKI: Reason: CAName: GenCRL:false} CAInfo:{CAName:} CAName: CSP:0xc42016df80}
2018/07/22 02:52:31 [DEBUG] Entered runEnroll
.
. 
.
2018/07/22 02:52:31 [DEBUG] Sending request
POST https://ica-org1.org1:7054/enroll
{"hosts":["register-p-org1-66bd5688b4-fhzmh"],"certificate_request":"-----BEGIN CERTIFICATE REQUEST-----\nMIIBXzCCAQYCAQAwZjELMAkGA1UEBhMCVVMxFzAVBgNVBAgTDk5vcnRoIENhcm9s\naW5hMRQwEgYDVQQKEwtIeXBlcmxlZGdlcjEPMA0GA1UECxMGRmFicmljMRcwFQYD\nVQQDEw5pY2Etb3JnMS1hZG1pbjBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABC5+\n+w04ZAjYiZDBzfc779+oYekJ2TURk6KqxL2Bw6BQXt251kh9VSScLrpb7qTCPMUF\nsg7pbTzsxyaauWu/fAGgPjA8BgkqhkiG9w0BCQ4xLzAtMCsGA1UdEQQkMCKCIHJl\nZ2lzdGVyLXAtb3JnMS02NmJkNTY4OGI0LWZoem1oMAoGCCqGSM49BAMCA0cAMEQC\nIBgeEW7fya+V0+7E8EgMdTV+krDiZsouX9ZsR+C6yf5KAiBrDLMMTb7y697HrROR\nax/7/enFQc78wboYRV3fjTEnEA==\n-----END CERTIFICATE REQUEST-----\n","profile":"","crl_override":"","label":"","NotBefore":"0001-01-01T00:00:00Z","NotAfter":"0001-01-01T00:00:00Z","CAName":""}
2018/07/22 02:52:32 [DEBUG] Received response
statusCode=201 (201 Created)
2018/07/22 02:52:32 [DEBUG] Response body result: map[Cert:LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUNYVENDQWdPZ0F3SUJBZ0lVUVI3ZmNXbVlHQVVnemFkSE5LWDY3cnRHOEw4d0NnWUlLb1pJemowRUF3SXcKWmpFTE1Ba0dBMVVFQmhNQ1ZWTXhGekFWQmdOVkJBZ1REazV2Y25Sb0lFTmhjbTlzYVc1aE1SUXdFZ1lEVlFRSwpFd3RJZVhCbGNteGxaR2RsY2pFUE1BMEdBMVVFQ3hNR1kyeHBaVzUwTVJjd0ZRWURWUVFERXc1eVkyRXRiM0puCk1TMWhaRzFwYmpBZUZ3MHhPREEzTWpJd01qUTRNREJhRncweE9UQTNNakl3TWpVek1EQmFNR1l4Q3pBSkJnTlYKQkFZVEFsVlRNUmN3RlFZRFZRUUlFdzVPYjNKMGFDQkRZWEp2YkdsdVlURVVNQklHQTFVRUNoTUxTSGx3WlhKcwpaV1JuWlhJeER6QU5CZ05WQkFzVEJtTnNhV1Z1ZERFWE1CVUdBMVVFQXhNT2FXTmhMVzl5WnpFdFlXUnRhVzR3CldUQVRCZ2NxaGtqT1BRSUJCZ2dxaGtqT1BRTUJCd05DQUFRdWZ2c05PR1FJMkltUXdjMzNPKy9mcUdIcENkazEKRVpPaXFzUzlnY09nVUY3ZHVkWklmVlVrbkM2NlcrNmt3anpGQmJJTzZXMDg3TWNtbXJscnYzd0JvNEdPTUlHTApNQTRHQTFVZER3RUIvd1FFQXdJSGdEQU1CZ05WSFJNQkFmOEVBakFBTUIwR0ExVWREZ1FXQkJTc0M1K3JGUXFMCkM3aFM2T1A2Q3NtRVI3Y1kvekFmQmdOVkhTTUVHREFXZ0JSdlVPRlNVc3p2YXRvQVhkYThSSUxiZ0lFamFqQXIKQmdOVkhSRUVKREFpZ2lCeVpXZHBjM1JsY2kxd0xXOXlaekV0TmpaaVpEVTJPRGhpTkMxbWFIcHRhREFLQmdncQpoa2pPUFFRREFnTklBREJGQWlFQStDdms1alpIbXd4cFRZL3NWazdnam5yN2p3UUYvdUd6WUpXQ29LY2VUcklDCklFc0o3Y0xJZWUzVVBwdFhKMjZCdml0a2Z1NUpWb2dTaFIxcVNFM2FTN1lmCi0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K ServerInfo:map[CAName:ica-org1.org1 CAChain:LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUNNakNDQWRtZ0F3SUJBZ0lVYjV0ZlNKUFZqVUtFZ2NWckY5S3hDczFHMUprd0NnWUlLb1pJemowRUF3SXcKWlRFTE1Ba0dBMVVFQmhNQ1ZWTXhGekFWQmdOVkJBZ1REazV2Y25Sb0lFTmhjbTlzYVc1aE1SUXdFZ1lEVlFRSwpFd3RJZVhCbGNteGxaR2RsY2pFUE1BMEdBMVVFQ3hNR1JtRmljbWxqTVJZd0ZBWURWUVFERXcxeVkyRXRiM0puCk1TNXZjbWN4TUI0WERURTRNRGN5TWpBeU5EY3dNRm9YRFRJek1EY3lNVEF5TlRJd01Gb3daakVMTUFrR0ExVUUKQmhNQ1ZWTXhGekFWQmdOVkJBZ1REazV2Y25Sb0lFTmhjbTlzYVc1aE1SUXdFZ1lEVlFRS0V3dEllWEJsY214bApaR2RsY2pFUE1BMEdBMVVFQ3hNR1kyeHBaVzUwTVJjd0ZRWURWUVFERXc1eVkyRXRiM0puTVMxaFpHMXBiakJaCk1CTUdCeXFHU000OUFnRUdDQ3FHU000OUF3RUhBMElBQkpXaXlhbjNGREJiWXZyNlVZNWlwMkJMYXFJYzA2UVAKRFc4RXd4ZVphZzREbllTWDlodytLRStkTVV4QmlkaUlWaUpqUVAwOGRic3NkeVJ3Q3pGbkY4R2paakJrTUE0RwpBMVVkRHdFQi93UUVBd0lCQmpBU0JnTlZIUk1CQWY4RUNEQUdBUUgvQWdFQU1CMEdBMVVkRGdRV0JCUnZVT0ZTClVzenZhdG9BWGRhOFJJTGJnSUVqYWpBZkJnTlZIU01FR0RBV2dCVDhWUGluVXdkclU5U2dhcDYzdktRYlZuQVkKTmpBS0JnZ3Foa2pPUFFRREFnTkhBREJFQWlCdllIOXhLZlg4bGZmZlpFZnp0NUhDSDUxRWsvZDh4em4zV1NRNwpwaHRjVndJZ0kwRHdtaVVVSmZVZDVpSXUrU0lyMXNDT3VvQ1JjZ0ZsMjNaMENReENSc2M9Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0KLS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUNFVENDQWJlZ0F3SUJBZ0lVZXRScVMzbW9TbWZiZDBSTVc5cTBaQlJ1ZU1Jd0NnWUlLb1pJemowRUF3SXcKWlRFTE1Ba0dBMVVFQmhNQ1ZWTXhGekFWQmdOVkJBZ1REazV2Y25Sb0lFTmhjbTlzYVc1aE1SUXdFZ1lEVlFRSwpFd3RJZVhCbGNteGxaR2RsY2pFUE1BMEdBMVVFQ3hNR1JtRmljbWxqTVJZd0ZBWURWUVFERXcxeVkyRXRiM0puCk1TNXZjbWN4TUI0WERURTRNRGN5TWpBeU5EY3dNRm9YRFRNek1EY3hPREF5TkRjd01Gb3daVEVMTUFrR0ExVUUKQmhNQ1ZWTXhGekFWQmdOVkJBZ1REazV2Y25Sb0lFTmhjbTlzYVc1aE1SUXdFZ1lEVlFRS0V3dEllWEJsY214bApaR2RsY2pFUE1BMEdBMVVFQ3hNR1JtRmljbWxqTVJZd0ZBWURWUVFERXcxeVkyRXRiM0puTVM1dmNtY3hNRmt3CkV3WUhLb1pJemowQ0FRWUlLb1pJemowREFRY0RRZ0FFVy9sNCt4STdhODlGczRXTUorcXNuWlJUenZ1c1FrUTMKbjd2dVdGdW1aaWVjUXZINkNsR1k5UTVFbHVQdWgyTWZ5akw4elpIM2R0WWpoMFdUZ1B2aUg2TkZNRU13RGdZRApWUjBQQVFIL0JBUURBZ0VHTUJJR0ExVWRFd0VCL3dRSU1BWUJBZjhDQVFFd0hRWURWUjBPQkJZRUZQeFUrS2RUCkIydFQxS0JxbnJlOHBCdFdjQmcyTUFvR0NDcUdTTTQ5QkFNQ0EwZ0FNRVVDSVFDV3poL0d3a3dxeEUxTmgvRHoKa1VKb2N5ckh1bDdFYStoNmJxWC90ak9xR2dJZ1hNQ0N4L3BDUS9LRkhmL2xSTllDeGQySy91NUxLS3ZwejBCeQo1U1BNUCtnPQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg== Version:]]
2018/07/22 02:52:32 [DEBUG] newEnrollmentResponse ica-org1-admin
2018/07/22 02:52:32 [INFO] Stored client certificate at /root/cas/ica-org1.org1/msp/signcerts/cert.pem
2018/07/22 02:52:32 [INFO] Stored root CA certificate at /root/cas/ica-org1.org1/msp/cacerts/ica-org1-org1-7054.pem
2018/07/22 02:52:32 [INFO] Stored intermediate CA certificates at /root/cas/ica-org1.org1/msp/intermediatecerts/ica-org1-org1-7054.pem
##### 2018-07-22 02:52:32 Registering michaelpeer1-org1 with ica-org1.org1
2018/07/22 02:52:32 [DEBUG] Home directory: /root/cas/ica-org1.org1
.
. 
.
2018/07/22 02:52:32 [DEBUG] Sending request
POST https://ica-org1.org1:7054/register
{"id":"michaelpeer1-org1","type":"peer","secret":"michaelpeer1-org1pw","affiliation":"org1"}
2018/07/22 02:52:32 [DEBUG] Received response
statusCode=201 (201 Created)
2018/07/22 02:52:32 [DEBUG] Response body result: map[secret:michaelpeer1-org1pw]
2018/07/22 02:52:32 [DEBUG] The register request completed successfully
Password: michaelpeer1-org1pw
##### 2018-07-22 02:52:32 Finished registering peer for org org1
```

### Step 9: Start the peer
We are now ready to start the new peer. The peer runs as a pod in Kubernetes. Let's take a look at the pod spec before
we deploy it. Replace 'michaelpeer1' with the name of your peer, and replace 'org5' with the org you selected. If you 
are unsure, you can simply do 'ls k8s' to view the yaml files that were generated based on your selections, and find
the file start starts with 'fabric-deployment-remote-peer-'.

```bash
more k8s/fabric-deployment-remote-peer-michaelpeer1-org1.yaml
```

There are a few things of interest in the pod yaml file:

* The pod specifies 2 containers: couchdb, a key-value store which stores the Fabric world state, and the peer itself
* The peer is bootstrapped using a script, which you can view by opening 'scripts/start-peer.sh'
* The peer is exposed using a Kubernetes service

So let's deploy the peer and check the logs:

```bash
kubectl apply -f k8s/fabric-deployment-remote-peer-michaelpeer1-org1.yaml
kubectl logs deploy/michaelpeer1-org1 -n org1 -c michaelpeer1-org1
```

You'll see a large number of log entries, which you are free to look at. The most important entries are a few
lines from the end of the log file. Look for these, and make sure there are no errors after these lines:

```bash
2018-07-22 03:05:49.145 UTC [nodeCmd] serve -> INFO 1ca Starting peer with ID=[name:"michaelpeer1-org1" ], network ID=[dev], address=[100.96.2.149:7051]
2018-07-22 03:05:49.146 UTC [nodeCmd] serve -> INFO 1cb Started peer with ID=[name:"michaelpeer1-org1" ], network ID=[dev], address=[100.96.2.149:7051]
```

If you can't find the entries, try grep:

```bash
kubectl logs deploy/michaelpeer1-org1 -n org1 -c michaelpeer1-org1 | grep 'Started peer'
```

Your peer has started, but..... it's useless at this point. It hasn't joined any channels, it can't run chaincode
and it does not maintain any ledger state. To start building a ledger on the peer we need to join a channel.
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

### Deploy Marbles
Marbles requires connectivity to three Fabric components:

* Orderer: the Orderer was created by the facilitator before the workshop started. The facilitator will provide the endpoint
* Peer: this is the peer you started in step 9. We will expose this using an NLB below (NLB because peers communicate using gRPC)
* CA: this is the CA you started in step 8. We will expose this using an ELB below (ELB because the CA server exposes a REST API)

Marbles requires changes to the config/connection_profile_tls.json file.

NOTE: Marbles running locally cannot connect to the ELB port 7054 if you are running your VPN software. Please
stop the VPN before connecting.

I also needed to 