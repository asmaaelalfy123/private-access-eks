# How to Create a Fully Private AWS EKS Cluster

## 📋 Overview

This comprehensive tutorial demonstrates how to create a **fully private Amazon EKS (Elastic Kubernetes Service) cluster** with no public endpoints. Perfect for organizations requiring enhanced security, compliance, and network isolation.

### 🎯 What You'll Learn

- ✅ Design and implement a fully private EKS cluster architecture
- ✅ Configure VPC networking for complete isolation
- ✅ Set up private API server endpoints
- ✅ Implement secure bastion host access patterns
- ✅ Deploy workloads in a completely private environment
- ✅ Manage ECR (Elastic Container Registry) access via VPC endpoints
- ✅ Automate everything using Terraform


## 🚀 Quick Start

### Prerequisites

Before you begin, ensure you have:

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0 installed
- kubectl installed
- Basic understanding of AWS networking and EKS
- AWS account with permissions to create VPC, EKS, IAM resources

### 📦 Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/asmaaelalfy123/private-access-eks.git
   
   ```


2. **Review and customize variables**
   ```bash
   # Edit terraform.tfvars
   vim terraform.tfvars
   ```

3. **Initialize Terraform**
   ```bash
   terraform init
   ```

4. **Plan the deployment**
   ```bash
   terraform plan
   ```

5. **Deploy the infrastructure**
   ```bash
   terraform apply
   ```

6. **Configure kubectl**
   ```bash
   aws eks update-kubeconfig --name private-eks-cluster --region us-east-1
   ```



## Configuration

### Key Terraform Variables

```hcl
# VPC Configuration
vpc_cidr            = "10.0.0.0/16"
availability_zones  = ["us-east-1a", "us-east-1b"]
private_subnets     = ["10.0.1.0/24", "10.0.2.0/24"]

# EKS Configuration
cluster_name        = "private-eks-cluster"
cluster_version     = "1.31"
endpoint_private    = true
endpoint_public     = false  # Completely private!

# Node Group Configuration
node_instance_types = ["t3.medium"]
desired_size        = 2
min_size            = 2
max_size            = 4
```

```
configuration for openvpn on ec2
```bash
sudo apt-get update && sudo apt-get -y upgrade
curl -fsSL https://swupdate.openvpn.net/repos/repo-public.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/openvpn.gpg
echo "deb [signed-by=/etc/apt/keyrings/openvpn.gpg] http://build.openvpn.net/debian/openvpn/stable $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/openvpn.list
sudo apt-get update
sudo apt-get install -y openvpn
wget https://github.com/OpenVPN/easy-rsa/releases/download/v3.2.4/EasyRSA-3.2.4.tgz
tar -zxf EasyRSA-3.2.4.tgz
sudo mv EasyRSA-3.2.4/ /etc/openvpn/easy-rsa
sudo ln -s /etc/openvpn/easy-rsa/easyrsa /usr/local/bin/
cd /etc/openvpn/easy-rsa
easyrsa init-pki
easyrsa build-ca nopass
easyrsa gen-req openvpn-server nopass
easyrsa sign-req server openvpn-server
openvpn --genkey secret ta.key
sudo vim /etc/sysctl.conf
sudo sysctl -p
sudo iptables -t nat -S
ip route list default
sudo iptables -t nat -I POSTROUTING -s 10.8.0.0/24 -o ens5 -j MASQUERADE
sudo apt-get install iptables-persistent
sudo vim /etc/openvpn/server/server.conf
cat /etc/passwd | grep nobody
cat /etc/group | grep nogroup
sudo systemctl start openvpn-server@server
sudo systemctl status openvpn-server@server
sudo systemctl enable openvpn-server@server
journalctl --no-pager --full -u openvpn-server@server -f
easyrsa gen-req example-1 nopass
easyrsa sign-req client example-1
cat /etc/openvpn/easy-rsa/pki/ca.crt
cat /etc/openvpn/easy-rsa/pki/issued/example-1.crt
cat /etc/openvpn/easy-rsa/pki/private/example-1.key
cat /etc/openvpn/easy-rsa/ta.key
netstat -nr -f inet
journalctl --no-pager --full -u openvpn-server@server -f
```

 Via VPN Connection

```bash
# Set up AWS Client VPN 
# Connect to VPN
# Access cluster directly
```

## 📊 Verification

Run these commands to verify your private cluster setup:

```bash
# Check cluster endpoint configuration
aws eks describe-cluster --name private-eks-cluster \
  --query 'cluster.resourcesVpcConfig.endpointPublicAccess'
# Output should be: false

# Verify nodes are running
kubectl get nodes

# Check VPC endpoints
aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=vpc-xxxxx"

# Test private ECR access
docker pull <account-id>.dkr.ecr.<region>.amazonaws.com/myapp:latest
```

##  Key Concepts Explained

### Why Fully Private?

1. **Enhanced Security**: No public endpoints reduce attack surface
2. **Compliance**: Meets strict regulatory requirements (PCI-DSS, HIPAA, etc.)
3. **Data Sovereignty**: All traffic stays within AWS network
4. **Network Isolation**: Complete control over network boundaries

### Private vs Public EKS Clusters

| Feature | Public Cluster | Private Cluster |
|---------|---------------|-----------------|
| API Endpoint | Public + Private | Private Only |
| Node Internet | Via IGW/NAT | Via VPC Endpoints |
| kubectl Access | From anywhere | Within VPC only |
| Container Images | Pull from anywhere | ECR via VPC endpoint |
| Security Posture | Standard | Maximum |

## Testing

Deploy a sample application to test the cluster:

```bash
# Apply sample deployment
kubectl apply -f kubernetes/deployment.yaml

# Check deployment status
kubectl get deployments
kubectl get pods

# Test service connectivity
kubectl get services
```


##  Cleanup

To destroy all resources:

```bash
# Delete Kubernetes resources first
kubectl delete -f kubernetes/

# Destroy Terraform infrastructure
terraform destroy
```

