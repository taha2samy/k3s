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

# IMPORTANT FIX: Create PriorityClasses here if not present.
# This prevents the "no PriorityClass with name system-node-critical was found" error.
# This part is executed after the kubeadm init.
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

echo "Kubernetes master node setup completed."