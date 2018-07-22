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

### Step 8: Register Fabric user with the Fabric certificiate authority
Before we can start our Fabric peer we must register it with the Fabric certificate authority (CA). This step
will start Fabric CA and register our peer:

```bash
./workshop-remote-peer/start-remote-fabric-setup.sh
```

### Step 9:



We are now ready to start the new peer. SSH into the EC2 instance you created in Step 2, navigate to the `fabric-on-eks` 
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
