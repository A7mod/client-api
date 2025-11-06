# Client API Assessment

This repository contains the code and Kubernetes manifests for the **Clients API** project, developed in **Go** using **Fiber** and **MongoDB** as a datastore. It is designed to run on **AWS EKS** and can be deployed via a CI/CD pipeline using **Jenkins**.

The API exposes endpoints for health checks and retrieving client counts from the database. The setup includes a load balancer, TLS certificates via **Let's Encrypt**, and an ALB ingress.

---

## 📁 Repository Structure
