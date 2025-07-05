
# Deploying a Kubernetes Cluster on AWS with Terraform & Kubeadm

![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-232F3E?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![Kubeadm](https://img.shields.io/badge/Kubeadm-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)

## Overview

This project provides a robust, automated solution for deploying a Kubernetes cluster on AWS. It leverages Terraform for infrastructure provisioning and `kubeadm` with Cloud-init for bootstrapping and configuring the nodes.

The architecture is fully automated, from creating the network infrastructure and EC2 instances to initializing the master node, installing the Calico CNI, and seamlessly joining worker nodes to the cluster. This project evolved from an initial Ansible-based implementation into a pure Infrastructure as Code (IaC) solution, incorporating battle-tested configurations to handle common deployment challenges.

## Key Features

-   **Fully Automated:** A single `terraform apply` command provisions the entire cluster.
-   **Modular Design:** The Terraform configuration is structured into reusable modules (VPC, Master, Worker) for clarity and maintainability.
-   **Cloud-init Bootstrapping:** Nodes are configured on first boot using Cloud-init, eliminating the need for configuration management tools like Ansible after provisioning.
-   **Robust Configuration:** Includes fixes for common `kubeadm` deployment issues, ensuring a stable and functional cluster out-of-the-box.
-   **Secure Key Management:** Automatically generates and saves an SSH key pair for instance access.

## Architecture

The project is structured using Terraform modules to ensure separation of concerns:

-   **VPC Module (`modules/vpc`):** Manages all networking components, including the VPC, public subnets, Internet Gateway, route tables, and distinct security groups for the master and worker nodes.
-   **Master Node Module (`modules/master-node`):** Provisions the control plane EC2 instance. A `cloud-init` script handles installing prerequisites, running `kubeadm init`, applying the Calico CNI, and generating the `kubeadm` join command for worker nodes.
-   **Worker Node Module (`modules/worker-node`):** Provisions worker EC2 instances using an Auto Scaling Group for scalability and resilience. The `cloud-init` script on each worker executes the `kubeadm join` command and handles self-labeling after a successful join.
-   **Root Module (`main.tf`):** Orchestrates the deployment by calling the other modules, generating the SSH key pair, and passing data (like the join command and `kubeconfig`) between modules.

## Project Structure

```
.
├── main.tf
├── variables.tf
├── outputs.tf
├── README.md
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── master-node/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── templates/
│   │       └── master-cloud-init.sh.tpl
│   └── worker-node/
│       ├── main.tf
│       ├── variables.tf
│       └── templates/
│           └── worker-cloud-init.sh.tpl
└── scripts/
    └── common-k8s-prereqs.sh.tpl
```

## Prerequisites

Before you begin, ensure you have the following installed and configured:
1.  **Terraform:** [Install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
2.  **AWS CLI:** [Install and Configure AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html) (with active credentials).

## Deployment Steps

1.  **Clone the Repository:**
    ```bash
    git clone <your-repo-url>
    cd <your-repo-name>
    ```

2.  **Initialize Terraform:**
    This command downloads the necessary providers (AWS, TLS, Local).
    ```bash
    terraform init
    ```

3.  **Deploy the Infrastructure:**
    This command will create all AWS resources and provision the Kubernetes cluster. The process will take several minutes to complete.
    ```bash
    terraform apply --auto-approve
    ```

## Connecting to Your Cluster

Once the deployment is complete, Terraform will generate two important files in the project's root directory:
-   `kubeconfig-master.conf`: The configuration file needed by `kubectl` to connect to your cluster.
-   `my-k8s-cluster-ssh-key.pem`: The private SSH key for accessing the EC2 instances.

#### 1. Configure `kubectl`

Point your `KUBECONFIG` environment variable to the generated file to interact with your cluster.

```bash
export KUBECONFIG=./kubeconfig-master.conf
```

#### 2. Verify Cluster Status

Check the status of your nodes. It may take a few moments for all worker nodes to join and report a `Ready` status.

```bash
kubectl get nodes
```

You should see output similar to this:
```
NAME           STATUS   ROLES           AGE   VERSION
controlplane   Ready    control-plane   5m    v1.28.x
ip-10-0-1-XX   Ready    worker          3m    v1.28.x
ip-10-0-2-YY   Ready    worker          3m    v1.28.x
```

#### 3. SSH Access (Optional)

You can SSH into any of the nodes using the generated private key.

```bash
# Get a node's public IP from the AWS Console or Terraform output
chmod 400 my-k8s-cluster-ssh-key.pem
ssh -i my-k8s-cluster-ssh-key.pem ubuntu@<NODE_PUBLIC_IP>
```

## Destroying the Infrastructure

To avoid ongoing charges, destroy all the resources created by Terraform when you are finished.

```bash
terraform destroy --auto-approve
```

## Deployment in Action

![test](img/pasted%20file.png)

![Cluster Setup](img/pasted%20file.png)
