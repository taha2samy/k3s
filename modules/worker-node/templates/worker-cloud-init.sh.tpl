#!/bin/bash
set -euxo pipefail

exec > >(tee /var/log/cloud-init-kubernetes.log) 2>&1

${common_prereqs_script}

if [ ! -f "/etc/kubernetes/pki/ca.crt" ]; then
    printf "%s" "${kubeadm_join_command}" | sudo bash
else
    echo "Worker node appears to have already joined the cluster (ca.crt exists)."
fi

mkdir -p "/home/${ansible_user}/.kube"
echo "${kubeconfig_content}" | sudo tee "/home/${ansible_user}/.kube/config" >/dev/null
sudo chmod 600 "/home/${ansible_user}/.kube/config"
sudo chown -R ${ansible_user}:${ansible_user} "/home/${ansible_user}/.kube"

KUBECONFIG_FILE="/home/${ansible_user}/.kube/config"
NODE_NAME=$(curl -s http://169.254.169.254/latest/meta-data/local-hostname)

export KUBECONFIG="$KUBECONFIG_FILE"

sudo -u ${ansible_user} timeout 480 bash -c ' \
  while ! kubectl get node '"worker"' &> /dev/null; do \
    echo "Waiting for node '"worker"' to register..."; \
    sleep 10; \
  done'

sudo -u ${ansible_user} timeout 480 bash -c ' \
  while ! kubectl wait --for=condition=Ready node/'"worker"' --timeout=20s &> /dev/null; do \
    echo "Waiting for node worker to become Ready..."; \
    sleep 10; \
  done'

  sudo -u ${ansible_user} kubectl label node "worker" node-role.kubernetes.io/worker= --overwrite=true

echo "SUCCESS: Worker node joined and labeled."