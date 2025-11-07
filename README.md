# Client API Assessment

This repository contains the code and Kubernetes manifests for the **Clients API** project, developed in **Go** using **Fiber** and **MongoDB** as a datastore. It is designed to run on **AWS EKS** and can be deployed via a CI/CD pipeline using **Jenkins**.

The API exposes endpoints for health checks and retrieving client counts from the database. The setup includes a load balancer, TLS certificates via **Let's Encrypt**, and an ALB ingress.

---

## 📁 Repository Structure

```
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
| ├── service.yaml
| ├── secret.yaml
│ └── cluster-issuer.yaml
│
├── Dockerfile # Builds the Clients API container
└── Jenkinsfile # CI/CD pipeline configuration

```

## 🛠 Technologies Used

- **Go** (Fiber framework)
- **MongoDB**
- **Docker**
- **Kubernetes**
- **AWS EKS**
- **ALB Ingress**
- **cert-manager** for Let's Encrypt certificates
- **Jenkins** for CI/CD pipeline

## ⚡ Features

- `/health` endpoint for health checks.
- `/clients` endpoint to get client count from MongoDB.
- Kubernetes deployment with:
  - **MongoDB** as a persistent datastore
  - **Clients API** deployment and service
  - **Ingress** with ALB and TLS
  - **ClusterIssuer** for Let's Encrypt certificates
- CI/CD pipeline to build Docker image, push to ECR, and deploy manifests to Kubernetes.

1. **Create an EKS cluster using `eksctl`:**

```bash
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: clients-api-cluster
  region: us-east-1

nodeGroups:
  - name: ng-clients-api
    instanceType: t3g.medium
    desiredCapacity: 2
    ssh:
      allow: true
      publicKeyName: my-keypair

```

```bash
eksctl create cluster -f cluster.yaml
```

2. **Install the AWS Load Balancer Controller:**

```bash
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=<cluster-name> --set serviceAccount.create=false --set region=<region> --set vpcId=<vpc-id> --set image.tag=v2.4.7
```

3. **Install cert-manager for Let's Encrypt TLS:**

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml
```

4. **Apply Kubernetes manifests:**

```bash
kubectl apply -f k8s/mongodb.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/cluster-issuer.yaml
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/secret.yaml
```

5. **Jenkins CI/CD Pipeline:**

- Build Docker image and push to AWS ECR.

- Apply Kubernetes manifests using kubectl through Jenkins.

# Required Jenkins plugins:

- Slack Notification
- AWS Steps
- Kubernetes
- Docker Pipeline
- AnsiColor
- Pipeline Utility Steps

# Required Jenkins Credentials:

- aws-ecr: AWS credentials
- slack-token: Slack integration token
- Environment Variables to Set:
- AWS_ACCOUNT_ID: Your AWS account ID
- Update cluster names in deployToKubernetes() function

```
- This pipeline is now enterprise-grade and follows DevOps best practices!
```

# 🐳 Dockerfile

The Dockerfile uses a **multi-stage build** to produce a small, secure, and production-ready image for the `clients-api` Go application:

1. **Stage 1 – Build Stage**

   - Uses `golang:1.21-alpine` as the builder.
   - Copies `go.mod` and `go.sum` first to leverage layer caching for dependencies.
   - Copies the application source code and builds an optimized **static binary** with versioning information injected via build arguments (`BUILD_VERSION`, `GIT_COMMIT`, `BUILD_DATE`).
   - Produces a statically linked, minimal `clients-api` binary.

2. **Stage 2 – Runtime Stage**

   - Uses a lightweight `alpine:3.19` image for runtime.
   - Creates a **non-root user** for security.
   - Copies the compiled binary from the builder stage with proper ownership.
   - Sets the working directory and ensures the application runs as the non-root user.
   - Specifies the default command to run the application: `./clients-api`.

# ⚙️ Jenkinsfile

This Jenkinsfile defines a **full CI/CD pipeline** for the `clients-api` Go application, building, testing, scanning, and deploying it to an **EKS Kubernetes cluster**. Key features include:

1. **Environment & Parameters**

   - Uses Jenkins-configured variables like `AWS_ACCOUNT_ID` to avoid hardcoding secrets.
   - Parameters allow deployment to `staging` or `production`, skipping tests or security scans, and choosing `kubectl` version.
   - Dynamic image tags using git commit SHA for traceability.

2. **Pipeline Stages**

   - **Initialization**: Prints build info and sets dynamic environment variables.
   - **Checkout**: Retrieves source code from Git and logs the last commit.
   - **Code Quality & Linting**: Runs `gofmt`, `go vet`, and optionally `golangci-lint` to enforce Go coding standards.
   - **Unit Tests**: Executes tests with coverage reporting and fails if coverage is below threshold.
   - **Build Docker Image**: Builds a Docker image tagged with commit SHA, build number, and `latest`.
   - **Security Scan**: Uses Trivy to scan Docker images for vulnerabilities.
   - **Push to ECR**: Authenticates to AWS ECR (without hardcoded credentials), tags, and pushes the Docker image.
   - **Update Kubernetes Manifests**: Updates deployment manifests with the new image tag.
   - **Deploy to EKS**: Deploys to `staging` or `production` using `kubectl`, manages namespaces and secrets, sets image, and annotates deployments.
   - **Health Check**: Ensures pods are running and optionally runs smoke tests.
   - **Tag Release**: Tags the Git repository for production releases.

3. **Post Actions & Notifications**

   - Always cleans up unused Docker images and temporary files.
   - Sends Slack notifications for **success**, **failure**, **unstable**, or **aborted** builds.
   - Includes retries, error handling, and manual approval for production deployments.

4. **Helper Functions**

   - `deployToKubernetes(environment)`: Handles EKS login, namespace creation, image pull secrets, and deployment.
   - `notifySlack(color, title, message)`: Sends formatted Slack notifications using the Slack plugin.
