# Hyperledger Fabric on Kubernetes - adding a new remote organisation

Configure and start a new Hyperledger Fabric organisation in one account, and join it to an existing Fabric network 
running in another account. Then add a peer to the new organisation and join an existing channel.

### Create a Kubernetes cluster in the new account
Repeat steps 1-7 under Getting Started in the main README in a different AWS account. You can also use a different region.

### What is the process for creating a new organisation?
In the AWS account & region where you want to host the new Fabric organisation, start a root CA, optionally start
an intermediate CA

### Configure the remote peer
