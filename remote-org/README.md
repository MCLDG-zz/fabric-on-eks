# Hyperledger Fabric on Kubernetes - adding a new remote organisation

Configure and start a new Hyperledger Fabric organisation in one account, and join it to an existing Fabric network 
running in another account. Then add a peer to the new organisation and join an existing channel.

This differs from other examples provided on the Internet, for example, http://hyperledger-fabric.readthedocs.io/en/release-1.1/channel_update_tutorial.html
and https://www.ibm.com/developerworks/cloud/library/cl-add-an-organization-to-your-hyperledger-fabric-blockchain/index.html.
These examples run a Fabric network on a single host, with all peers co-located, and the ability to share and use certs/keys
belonging to other organisations. Proper Fabric networks should be distributed, with members of the network potentially
being located in different regions and running their peers on different platforms or on-premise.

The README below will focus on integrating a new organisation into an existing Fabric network, where the new org could
be running its peers anywhere.

### Create a Kubernetes cluster in the new account
Repeat steps 1-7 under Getting Started in the main README in a different AWS account. You can also use a different region.

### What is the process for creating a new organisation?
The process for adding a new, remote organisation to an existing network is as follows:

* In an AWS account and/or region different from the main Fabric network, use fabric-CA to generate the certs and keys 
for the new organisation
* Copy the public certs/keys from the new org to the main Fabric network
* In the main Fabric network, an admin user generates a new config block for the new org and updates the channel config
with the new config. This will enable the new org to join an existing channel
* Copy the genesis block of the channel to the new org. Peers in the new org will use this to join the channel
* In the new org, start the peers and join the channel

### Obtain the certs/keys for the new org
In the AWS account & region where you want to host the new Fabric organisation, start a root CA, and optionally start
an intermediate CA.

To join a new Fabric organisation to an existing Fabric network, you need to copy the certificates for the new org
to the existing network. The certificates of interest are the admincerts, cacerts and tlscacerts found in the new
org's msp folder. This folder is located on the EFS drive here: /opt/share/rca-data/orgs/<org name>/msp

Copy the certificate and key information from the new org to the Fabric network in the main Kubernetes cluster, as follows:

* SSH into the EC2 instance you created in the new AWS account, which is hosting the new organisation
* In the home directory, execute `sudo tar cvf org7msp.tar  /opt/share/rca-data/orgs/org7/msp`, to zip up the org's msp
directory. Replace 'org7' with your org name
* Exit the SSH, back to your local laptop or host
* Copy the tar file to your local laptop or host using (replace with your directory name, EC2 DNS and keypair):
  `scp -i /Users/edgema/Documents/apps/eks/eks-fabric-key-account1.pem ec2-user@ec2-34-228-23-44.compute-1.amazonaws.com:/home/ec2-user/org7msp.tar /Users/edgema/Documents/apps/fabric-on-eks/org7msp.tar`
* Copy the tar file to your SSH EC2 host in your original AWS account (the one hosting the main Fabric network) using (replace with your directory name, EC2 DNS and keypair): 
 `scp -i /Users/edgema/Documents/apps/eks/eks-fabric-key.pem org7msp.tar ec2-user@ec2-18-236-169-96.us-west-2.compute.amazonaws.com:/home/ec2-user/org7msp.tar`
* SSH into the EC2 instance in your original Kubernetes cluster in your original AWS account
* `cd /`
* `sudo tar xvf ~/org7msp.tar` - this should extract they certs for the new org onto the EFS drive, at /opt/share


### Configure the remote peer
