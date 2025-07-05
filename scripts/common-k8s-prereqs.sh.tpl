#!/bin/bash
set -euxo pipefail

# Redirect all output to a log file for debugging
exec > >(tee /var/log/cloud-init-kubernetes.log) 2>&1

echo "Starting common Kubernetes prerequisites setup..."

# Disable swap
echo "Disabling swap..."
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Load kernel modules and configure sysctl for Kubernetes
echo "Configuring kernel modules and sysctl parameters..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# Install containerd and runc
echo "Installing containerd and runc..."

# Install necessary packages for apt transport and GPG
apt update
apt install -y apt-transport-https ca-certificates curl gpg

# Install containerd using the official release tarball (mimicking Ansible)
CONTAINERD_VERSION="2.0.3"
CONTAINERD_TGZ="containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz"
CONTAINERD_URL="https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/${CONTAINERD_TGZ}"

if [ ! -f "/usr/local/bin/containerd" ]; then
    echo "Downloading and installing containerd..."
    curl -L "${CONTAINERD_URL}" -o "/tmp/${CONTAINERD_TGZ}"
    tar Cxzvf /usr/local "/tmp/${CONTAINERD_TGZ}"
    mkdir -p /usr/local/lib/systemd/system

    # Download containerd systemd service file
    curl -L https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -o /usr/local/lib/systemd/system/containerd.service
else
    echo "Containerd already installed."
fi

# Install runc
RUNC_VERSION="1.2.5"
RUNC_BIN="runc.amd64"
RUNC_URL="https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/${RUNC_BIN}"

if [ ! -f "/usr/local/sbin/runc" ]; then
    echo "Downloading and installing runc..."
    curl -L "${RUNC_URL}" -o "/tmp/${RUNC_BIN}"
    install -m 755 "/tmp/${RUNC_BIN}" /usr/local/sbin/runc
else
    echo "Runc already installed."
fi

# Install CNI plugins
CNI_VERSION="v1.6.2"
CNI_TGZ="cni-plugins-linux-amd64-${CNI_VERSION}.tgz"
CNI_URL="https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/${CNI_TGZ}"

if [ ! -d "/opt/cni/bin" ]; then
    echo "Downloading and installing CNI plugins..."
    mkdir -p /opt/cni/bin
    curl -L "${CNI_URL}" -o "/tmp/${CNI_TGZ}"
    tar Cxzvf /opt/cni/bin "/tmp/${CNI_TGZ}"
else
    echo "CNI plugins already installed."
fi

# Configure containerd for systemd cgroup driver
echo "Configuring containerd..."
mkdir -p /etc/containerd
if ! grep -q "SystemdCgroup = true" /etc/containerd/config.toml; then
    containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
fi

echo "Enabling and starting containerd service..."
systemctl daemon-reload
systemctl enable containerd --now
systemctl restart containerd

echo "Verifying containerd status..."
ctr --address /var/run/containerd/containerd.sock info || true # Ignore error if it's not fully up yet

# Add Kubernetes apt repository
echo "Adding Kubernetes apt repository..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
chmod 0644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg # Ensure correct permissions
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

# Install kubeadm, kubelet, kubectl
echo "Installing kubeadm, kubelet, and kubectl..."
apt update
apt install -y kubeadm kubelet kubectl

# Enable and start kubelet service
echo "Enabling and starting kubelet service..."
systemctl enable kubelet --now
systemctl restart kubelet

echo "Common Kubernetes prerequisites setup completed."