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

---

## 📂 Repository Structure
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
  - Port **22** for SSH  
  - Port **8080** for Jenkins  
  - Port **80** for ELB traffic  

### 2. Install Tools
**On Workbench:**
```bash
sudo apt update -y
sudo apt install -y unzip git curl docker.io jq
# Install awscli, eksctl, kubectl
**On Jenkins EC2:**
sudo apt update -y
sudo apt install -y openjdk-17-jdk docker.io git curl unzip
# Install awscli, kubectl, Jenkins
sudo usermod -aG docker jenkins

### 3. Create EKS Cluster
export AWS_REGION=us-west-1
export CLUSTER=eks-demo-dipen

eksctl create cluster --name $CLUSTER --version 1.29 \
  --region $AWS_REGION --node-type t3.large --nodes 2

### 4. Create ECR Repository
export APP_NAME=hello-web
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws ecr create-repository \
  --repository-name $APP_NAME \
  --region $AWS_REGION

### 5. Configure Jenkins Pipeline
In Jenkins UI → New Item → Pipeline → Pipeline script from SCM → Git URL
Branch: main
Save → Build Now

### 6. Validate
kubectl -n demo get pods,svc

### Ouput
Open the ELB EXTERNAL-IP in a browser →
Hello from EKS via Jenkins CI/CD! 🚀

## 🌀 CI/CD Pipeline Overview

### Stages in Jenkinsfile:
Checkout → Pull latest repo from GitHub
Resolve AWS/ECR & Login → Fetch Account ID, ensure repo exists
Build & Smoke Test → Build Docker image, verify app locally
Push to ECR → Push tagged + latest images
Configure kubectl → Authenticate with EKS cluster
Deploy to EKS → Apply manifests, patch deployment image, wait for rollout
Rollback → If rollout fails, revert to previous image

## 🌐 Demo Application

### Minimal Node.js server:
const http = require('http');
http.createServer((req,res)=>{
  res.writeHead(200, {'Content-Type':'text/plain'});
  res.end('Hello from EKS via Jenkins CI/CD! 🚀\n');
}).listen(3000);

## 🧹 Cleanup

### To avoid AWS charges:
eksctl delete cluster --name $CLUSTER --region $AWS_REGION
aws ecr delete-repository --repository-name hello-web --region $AWS_REGION --force
# Terminate EC2 instances (Workbench & Jenkins)

## 📌 Notes

## This setup is for demo/learning purposes.
# For production:
Use Amazon Linux 2023 or Bottlerocket AMIs for nodes
Enable CloudWatch logging & monitoring
Replace AdministratorAccess with least-privilege IAM
Use Ingress + AWS Load Balancer Controller + ACM TLS for HTTPS