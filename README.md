# ☁️ Culinary Platform on Kubernetes (AWS EKS)
This repository demonstrates the deployment of a full-stack web application (Django + React + PostgreSQL) in the **Amazon Web Services** (AWS) cloud using the managed Kubernetes service, **EKS**. 
The project is built following Infrastructure as Code (IaC), CI/CD principles, and includes monitoring.

The goal is to showcase skills in using modern cloud and DevOps tools to build, deploy, and maintain scalable applications.

# 🏛️ Architecture
The project features a containerized architecture where each component is deployed and scaled independently within AWS EKS.

**Core Component Interaction:**
1. **Terraform:** Creates and manages all necessary infrastructure in AWS (VPC, Subnets, EKS Cluster, Node Group, ECR Repositories, S3 bucket, and DynamoDB table for Terraform state).
2. **Docker:** Containerizes the Backend (Django) and Frontend (React) applications.
3. **AWS ECR (Elastic Container Registry):** Private registry for storing Docker images.
4. **GitHub Actions (CI/CD):** Automates the process:
   * Applying infrastructure changes (`terraform apply`).
   * Building Docker images upon code changes.
   * Pushing images to ECR.
   * Deploying updated application versions to EKS using Helm.
5. **AWS EKS (Elastic Kubernetes Service)**: Orchestrates container workloads.
6. **Helm:** Package manager for Kubernetes, used for declarative deployment of applications (Backend, Frontend, PostgreSQL) and system components.
7. **AWS Load Balancer Controller**: Automatically creates and manages an Application Load Balancer (ALB) to route external traffic to services based on Kubernetes Ingress resources.
8. **AWS EBS CSI Driver**: Enables Kubernetes to dynamically provision and manage persistent storage volumes (EBS Volumes) for stateful applications (PostgreSQL).
9. **Prometheus & Grafana**: Collect and visualize cluster and application metrics.
# ✨ Key Features
* **Infrastructure as Code (IaC)**: 100% of the infrastructure (EKS, VPC, ECR) is managed via Terraform, ensuring reproducibility and versioning. State is stored remotely in S3 with locking via DynamoDB.
*** Containerization**: Docker is used to package the applications and their dependencies.
* **Orchestration**: EKS provides scaling, resilience, and management for containers.
* **CI/CD Automation**: Three independent GitHub Actions pipelines (for Terraform, backend, and frontend) trigger on changes in respective directories, using OIDC for secure AWS authentication.
* **Deployment Management**: Helm is used for templating and managing the lifecycle of Kubernetes applications.
* **Ingress Traffic**: AWS Load Balancer Controller automatically configures an ALB for service access via Ingress.
* **Persistent Storage**: The AWS EBS CSI Driver integrates EKS with Amazon EBS for dynamic volume provisioning.
* **Monitoring**: A Prometheus + Grafana stack (installed via Helm) provides system observability.
* **Security**: Secrets are managed via GitHub Secrets and Kubernetes Secrets; AWS access uses OIDC without static keys.
# 🛠️ Tech Stack
| Category | Technology |
| ------------- | ------------- |
| Cloud & DevOps  | AWS, EKS, Terraform, Docker, Helm, Kubernetes, GitHub Actions, AWS Load Balancer Controller, EBS CSI Driver  |
| Backend  | Python, Django, Django REST Framework  |
| Frontend  | JavaScript, React, Vite  |
| Database  | PostgreSQL (StatefulSet + EBS Volume)  |
| Monitoring  | Prometheus, Grafana  |
| Infrastructure  | VPC, EC2 (EKS Nodes), S3, DynamoDB, ECR, IAM (OIDC)  |
# 🚀 Getting Started
**Prerequisites**
Installed and configured:
* [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) (with access credentials to your AWS account)
* [Terraform](https://developer.hashicorp.com/terraform/install) (~1.12.0)
* [Kubectl](https://kubernetes.io/docs/tasks/tools/)
* [Helm](https://helm.sh/docs/intro/install/)
* [Docker](https://www.docker.com/products/docker-desktop/)
* [eksctl](https://docs.aws.amazon.com/eks/latest/eksctl/installation.html) (for configuring controller access)
* [GitHub](https://github.com/) account.

### **1. Configure Terraform State Backend (One-time)**
Before running Terraform for the first time, manually create the S3 bucket and DynamoDB table for state storage:
```
# Replace <unique-bucket-name> and <region>
aws s3api create-bucket --bucket <unique-bucket-name> --region <region> --create-bucket-configuration LocationConstraint=<region>
aws dynamodb create-table --table-name terraform-state-lock --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 --region <region>
```
Edit the backend "s3" block in terraform/provider.tf with your bucket and table names.
### **2. Deploy Infrastructure (Terraform)**
1. Navigate to the terraform/ directory.
2. Create a terraform.tfvars file and add your IAM user ARN (admin_user_arn) that will get admin access to the cluster.
3. Run the commands:
```
terraform init
terraform apply
```
### 3. Configure Cluster Access
```
aws eks update-kubeconfig --name <your-eks-cluster-name> --region <your-region>
kubectl get nodes # Verify access
```
### 4. Cluster Setup (System Components)
a) AWS Load Balancer Controller
```
# Add repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Grant permissions (replace <account-id> and <region>)
$env:AWS_ACCOUNT_ID=(aws sts get-caller-identity --query "Account" --output text)
eksctl create iamserviceaccount `
  --cluster=<cluster-name> `
  --namespace=kube-system `
  --name=aws-load-balancer-controller `
  --attach-policy-arn=arn:aws:iam::$env:AWS_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy `
  --approve `
  --region <region>

# Install the controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller `
  -n kube-system `
  --set clusterName=<cluster-name> `
  --set serviceAccount.create=false `
  --set serviceAccount.name=aws-load-balancer-controller
```
b) AWS EBS CSI Driver & StorageClass
```
# Grant permissions
eksctl create iamserviceaccount `
  --cluster=<cluster-name> `
  --namespace=kube-system `
  --name=ebs-csi-controller-sa `
  --attach-policy-arn=arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy `
  --approve `
  --region <region>

# Install the driver
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm repo update
helm install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver --namespace kube-system `
    --set controller.serviceAccount.create=false `
    --set controller.serviceAccount.name=ebs-csi-controller-sa

# Create the StorageClass
kubectl apply -f cluster-setup/ebs-sc.yaml
```
### 5. Prepare Docker Images
1. Log in to ECR:
`aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com`
2. Build, tag, and push your images:
```
# Backend
docker build -t backend:latest ./backend
docker tag backend:latest <account-id>.dkr.ecr.<region>.amazonaws.com/backend:latest
docker push <account-id>.dkr.ecr.<region>.amazonaws.com/backend:latest

# Frontend (similarly)
docker build -t frontend:latest ./frontend
docker tag frontend:latest <account-id>.dkr.ecr.<region>.amazonaws.com/frontend:latest
docker push <account-id>.dkr.ecr.<region>.amazonaws.com/frontend:latest
```
### 6. Deploy Applications (Helm)
Important: There are two ways to handle secrets (passwords, keys):
**For Manual Deployment (locally)**:
* For the `database` and` helm-backend` charts, create secrets.yaml files by copying the `*.yaml.example` files.
* Fill these `secrets.yaml` files with your actual data. Do not commit these files to Git! (They should already be in `.gitignore`).
* Update the `values.yaml` for backend and frontend with the correct ECR repository addresses.
* Deploy components using the -f `secrets.yaml` flag:
```
# Database
helm install db-release ./database -f ./database/values.yaml -f ./database/secrets.yaml

# Backend
helm install backend-release ./helm-backend -f ./helm-backend/values.yaml -f ./helm-backend/secrets.yaml

# Frontend
helm install frontend-release ./helm-frontend
```
**For Automated Deployment (CI/CD via GitHub Actions)**:
  1. Do not create `secrets.yaml` files locally.
  2. Go to your GitHub repository settings: `Settings` > `Secrets and variables` > `Actions`.
  3. Add the required secrets (e.g., `AWS_ROLE_TO_ASSUME`, `DJANGO_SECRET_KEY`, `DATABASE_URL`).
  4. The pipelines (`deploy-backend.yml`, `deploy-frontend.yml`) will automatically fetch these secrets and pass them to Helm during deployment.

# 7. Access the Application
1. Wait a few minutes for the ALB to be provisioned.
2. Find the DNS address of your load balancer:
`kubectl get ingress`
3. Open this address in your browser. The backend is accessible via the `/api/` path.

# 📊 Monitoring (Prometheus + Grafana)
The monitoring stack is installed via Helm.
```
# Add repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install the stack (replace <YOUR_ALB_DNS_ADDRESS>)
helm install monitoring prometheus-community/kube-prometheus-stack `
  --namespace monitoring `
  --create-namespace `
  --set grafana.service.type=NodePort `
  --set grafana.grafana\.ini.server.root_url="http://<YOUR_ALB_DNS_ADDRESS>/grafana/" `
  --set grafana.grafana\.ini.server.serve_from_sub_path=true

# Create Ingress for Grafana (ensure grafana-ingress.yaml exists in monitoring/)
kubectl apply -f monitoring/grafana-ingress.yaml
```
Grafana will be accessible at` http://<YOUR_ALB_DNS_ADDRESS>/grafana`. Login/password: `admin`/`prom-operator`.

# 🔄 CI/CD Pipeline
This project uses three separate GitHub Actions workflows located in `.github/workflows/`:
 *  `terraform.yml`: Manages infrastructure. Shows `plan` in Pull Requests, runs `apply` on merge to main.
 * `deploy-backend.yml`: Builds and deploys the backend on changes in `backend/`.
 * `deploy-frontend.yml`: Builds and deploys the frontend on changes in `frontend/`.
Setup:
1. Create an IAM OIDC Identity Provider in AWS trusting GitHub Actions.
2. Create an IAM Role that trusts this provider and your repository, granting necessary permissions (for Terraform, ECR, EKS).
3. Add the ARN of this role as the AWS_ROLE_TO_ASSUME secret in GitHub.
4. Add DJANGO_SECRET_KEY and DATABASE_URL as secrets in GitHub.

# 📂 Project Structure
.<br>
├── .github/workflows/      # GitHub Actions CI/CD pipelines<br>
│   ├── terraform.yml <br>
│   ├── deploy-frontend.yml <br>
|   └── deploy-backend.yml <br>
├── backend/                # Django application source code <br>
├── frontend/               # React application source code <br>
├── database/               # Helm chart for PostgreSQL <br>
├── cluster-setup/          # StorageClass
├── monitoring/             # Grafana Ingress
├── helm-backend/           # Helm chart for Django <br>
├── helm-frontend/          # Helm chart for React <br>
└── terraform/              # Terraform code for infrastructure<br> 
