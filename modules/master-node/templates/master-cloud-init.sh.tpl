#!/bin/bash
set -euxo pipefail

# Common Kubernetes prerequisites script
${common_prereqs_script}

echo "Starting Kubernetes master node setup..."

# Set hostname
hostnamectl set-hostname controlplane

# Check if Kubernetes is already initialized
if [ ! -f "/etc/kubernetes/admin.conf" ]; then
    echo "Initializing Kubernetes cluster with kubeadm..."
    # --pod-network-cidr should match your CNI plugin's requirement (Calico uses 10.244.0.0/16 by default)
    kubeadm init --pod-network-cidr=10.244.0.0/16 --control-plane-endpoint="$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):6443"

    echo "Configuring kubectl for ${ansible_user} user..."
    mkdir -p "/home/${ansible_user}/.kube"
    # IMPORTANT FIX: Copy admin.conf AND set correct ownership/permissions for the ubuntu user
    # This ensures `kubectl` works without `sudo` for the ubuntu user
    sudo cp /etc/kubernetes/admin.conf "/home/${ansible_user}/.kube/config"
    sudo chown -R ${ansible_user}:${ansible_user} "/home/${ansible_user}/.kube"
    sudo chmod 0600 "/home/${ansible_user}/.kube/config" # Make it readable only by owner for security

    echo "Applying Calico CNI network plugin..."
    # Use the local kubeconfig for the ubuntu user to apply Calico
    # This assumes kube-apiserver is running and accessible
    /home/${ansible_user}/.kube/config kubectl --kubeconfig=/home/${ansible_user}/.kube/config apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml
else
    echo "Kubernetes cluster appears to be already initialized (admin.conf exists)."
fi


if ! sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf get priorityclass system-node-critical >/dev/null 2>&1; then
    echo "Creating system-node-critical and system-cluster-critical PriorityClasses..."
    cat <<EOF | sudo tee /etc/kubernetes/manifests/priority-classes.yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: system-node-critical
value: 2000000000
globalDefault: false
description: "Used for system critical pods that must not be evicted from a node."
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: system-cluster-critical
value: 1000000000
globalDefault: false
description: "Used for system critical pods that must not be evicted from a cluster."
EOF
    sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f /etc/kubernetes/manifests/priority-classes.yaml
fi

# --- ECR SECRET CREATION ---
echo "Configuring ECR Image Pull Secret..."

if ! command -v aws &> /dev/null; then
    sudo apt-get update
    sudo apt-get install -y awscli
fi

AWS_REGION=$$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
AWS_ACCOUNT_ID=$$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep accountId | awk -F\" '{print $$4}')
ECR_REGISTRY="$${AWS_ACCOUNT_ID}.dkr.ecr.$${AWS_REGION}.amazonaws.com"

ECR_SECRET_NAME="ecr-registry-secret"
DEFAULT_NAMESPACE="default"

ECR_PASSWORD=$$(aws ecr get-login-password --region "$${AWS_REGION}")

# Create the Kubernetes secret for ECR
sudo kubectl --kubeconfig=/home/${ansible_user}/.kube/config create secret docker-registry "$${ECR_SECRET_NAME}" \
  --docker-server="$${ECR_REGISTRY}" \
  --docker-username=AWS \
  --docker-password="$${ECR_PASSWORD}" \
  --namespace="$${DEFAULT_NAMESPACE}" \
  --dry-run=client -o yaml | sudo kubectl --kubeconfig=/home/${ansible_user}/.kube/config apply -f -

# Patch the default service account to use this secret
sudo kubectl --kubeconfig=/home/${ansible_user}/.kube/config patch serviceaccount default \
  -n "$${DEFAULT_NAMESPACE}" \
  -p "{\"imagePullSecrets\": [{\"name\": \"$${ECR_SECRET_NAME}\"}]}"

echo "ECR Image Pull Secret configured for the 'default' service account."