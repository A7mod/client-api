# Client API Assessment

This repository contains the code and Kubernetes manifests for the **Clients API** project, developed in **Go** using **Fiber** and **MongoDB** as a datastore. It is designed to run on **AWS EKS** and can be deployed via a CI/CD pipeline using **Jenkins**.

The API exposes endpoints for health checks and retrieving client counts from the database. The setup includes a load balancer, TLS certificates via **Let's Encrypt**, and an ALB ingress.

---

## 📁 Repository Structure

client-api/
│
├── api/
│ ├── main.go # Go application code
│ ├── go.mod
│ └── go.sum
│
├── k8s/ # Kubernetes manifests
│ ├── mongodb.yaml
│ ├── deployment.yaml
│ ├── ingress.yaml
│ └── cluster-issuer.yaml
│
├── Dockerfile # Builds the Clients API container
└── Jenkinsfile # CI/CD pipeline configuration

---

## 🛠 Technologies Used

- **Go** (Fiber framework)
- **MongoDB**
- **Docker**
- **Kubernetes**
- **AWS EKS**
- **ALB Ingress**
- **cert-manager** for Let's Encrypt certificates
- **Jenkins** for CI/CD pipeline

---

## ⚡ Features

- `/health` endpoint for health checks.
- `/clients` endpoint to get client count from MongoDB.
- Kubernetes deployment with:
  - **MongoDB** as a persistent datastore
  - **Clients API** deployment and service
  - **Ingress** with ALB and TLS
  - **ClusterIssuer** for Let's Encrypt certificates
- CI/CD pipeline to build Docker image, push to ECR, and deploy manifests to Kubernetes.

---

## 🚀 Steps to Recreate the Environment (For Fun)

> **Note:** You don’t need to actually run this — this is included for reference.

1. **Create an EKS cluster using `eksctl`:**

```bash
eksctl create cluster -f cluster.yaml


cluster.yaml contains cluster name, region, node groups, and other configurations.

This command creates the EKS cluster, VPC, subnets, and nodegroups automatically.

Install the AWS Load Balancer Controller:

kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=<cluster-name> --set serviceAccount.create=false --set region=<region> --set vpcId=<vpc-id> --set image.tag=v2.4.7
```
