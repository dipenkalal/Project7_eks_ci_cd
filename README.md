# 🚀 EKS + Jenkins + Docker CI/CD Demo

This project demonstrates a complete **CI/CD pipeline** for deploying a containerized Node.js application onto **Amazon EKS** using **Jenkins** and **Amazon ECR**.  

The setup is designed for **learning** and **reproducibility** — two EC2 instances act as the **Workbench (admin box)** and **Jenkins server**.

---

## 🏗️ Architecture

**Services used:**
- **Amazon EC2** – Workbench & Jenkins servers (Ubuntu 22.04)
- **Amazon EKS** – Kubernetes cluster for running the app
- **Amazon ECR** – Private Docker registry for container images
- **AWS IAM** – Access & role management for EC2 and Jenkins
- **Docker** – Containerization of Node.js app
- **Jenkins** – CI/CD automation
- **kubectl / eksctl** – CLI tools to manage EKS

**Pipeline flow:**
1. Developer pushes code to GitHub.  
2. Jenkins pipeline builds & smoke-tests Docker image.  
3. Image is pushed to Amazon ECR.  
4. Jenkins applies Kubernetes manifests & updates the deployment.  
5. App is served via AWS Load Balancer with external DNS.  

**Diagram:**  

![EKS Jenkins CI/CD Architecture](eks_jenkins_cicd_architecture.png)

---

## 📂 Repository Structure

```
.
├── Dockerfile
├── .dockerignore
├── server.js
├── package.json
├── namespace.yaml
├── deployment.yaml
├── service.yaml
├── Jenkinsfile
├── .env.aws
└── README.md
```

- **server.js** → Simple Node.js HTTP app (`Hello from EKS via Jenkins CI/CD! 🚀`)  
- **Dockerfile** → Builds a minimal `node:20-alpine` image  
- **Kubernetes manifests** → Namespace, Deployment, Service (LoadBalancer)  
- **Jenkinsfile** → Declarative pipeline: build → test → push → deploy (with rollback)  
- **.env.aws** → Optional environment values (Jenkins resolves dynamically)  

---

## ⚙️ Setup Instructions

### 1. Provision AWS Resources
- **2x EC2 (Ubuntu 22.04)** → Workbench + Jenkins  
- Attach IAM roles:  
  - Jenkins EC2 → `AmazonEKSClusterPolicy`, `AmazonEC2ContainerRegistryFullAccess`  
  - Nodegroup role → `AmazonEC2ContainerRegistryReadOnly`  
- Security groups:  
  - Port **22** → SSH  
  - Port **8080** → Jenkins  
  - Port **80** → ELB traffic  

### 2. Install Tools

**On Workbench:**
```bash
# Update system
sudo apt update -y
sudo apt upgrade -y

# Install base tools
sudo apt install -y unzip git curl docker.io jq

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version

# Install eksctl
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz"
tar -xzf eksctl_$(uname -s)_amd64.tar.gz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
eksctl version

# Install kubectl (latest stable)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
kubectl version --client

```

**On Jenkins EC2:**
```bash
# Update system
sudo apt update -y
sudo apt upgrade -y

# Install base tools
sudo apt install -y openjdk-17-jdk docker.io git curl unzip

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
kubectl version --client

# Install Jenkins
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | \
  sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt update -y
sudo apt install -y jenkins

# Add Jenkins user to Docker group
sudo usermod -aG docker jenkins

# Restart Jenkins service
sudo systemctl enable jenkins
sudo systemctl start jenkins
sudo systemctl status jenkins
```

### 3. Create EKS Cluster
```bash
# Set AWS region and cluster name
export AWS_REGION=us-west-1
export CLUSTER=eks-demo-dipen

# Create EKS cluster with 2 nodes (t3.large)
eksctl create cluster \
  --name $CLUSTER \
  --version 1.29 \
  --region $AWS_REGION \
  --node-type t3.large \
  --nodes 2
```

### 4. Create ECR Repository
```bash
# Set app name and fetch AWS account ID
export APP_NAME=hello-web
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create repository in ECR
aws ecr create-repository \
  --repository-name $APP_NAME \
  --region $AWS_REGION
```

### 5. Configure Jenkins Pipeline
- In Jenkins UI → **New Item → Pipeline → Pipeline script from SCM → Git URL**  
- Branch: `main`  
- Save → **Build Now**  

### 6. Validate
```bash
kubectl -n demo get pods,svc
```

**Output:**  
Open the **ELB EXTERNAL-IP** in a browser →  
`Hello from EKS via Jenkins CI/CD! 🚀`

---

## 🌀 CI/CD Pipeline Overview

**Stages in `Jenkinsfile`:**
1. **Checkout** → Pull latest repo from GitHub  
2. **Resolve AWS/ECR & Login** → Fetch Account ID, ensure repo exists  
3. **Build & Smoke Test** → Build Docker image, verify app locally  
4. **Push to ECR** → Push tagged + latest images  
5. **Configure kubectl** → Authenticate with EKS cluster  
6. **Deploy to EKS** → Apply manifests, patch deployment image, wait for rollout  
7. **Rollback** → If rollout fails, revert to previous image  

---

## 🌐 Demo Application

Minimal Node.js server:

```js
const http = require('http');
http.createServer((req,res)=>{
  res.writeHead(200, {'Content-Type':'text/plain'});
  res.end('Hello from EKS via Jenkins CI/CD! 🚀\n');
}).listen(3000);
```

---

## 🧹 Cleanup

To avoid AWS charges:

```bash
eksctl delete cluster --name $CLUSTER --region $AWS_REGION
aws ecr delete-repository --repository-name hello-web --region $AWS_REGION --force
# Terminate EC2 instances (Workbench & Jenkins)
```

---

## 📌 Notes

This setup is for **demo/learning purposes**.  

For production:
- Use **Amazon Linux 2023** or **Bottlerocket** AMIs for nodes  
- Enable **CloudWatch logging & monitoring**  
- Replace `AdministratorAccess` with **least-privilege IAM**  
- Use **Ingress + AWS Load Balancer Controller + ACM TLS** for HTTPS  

---

✨ Enjoy your fully automated **Code → Jenkins → ECR → EKS → ELB** pipeline!
