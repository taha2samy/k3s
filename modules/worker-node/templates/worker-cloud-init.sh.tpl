#!/bin/bash
set -euxo pipefail

exec > >(tee /var/log/cloud-init-kubernetes.log) 2>&1

${common_prereqs_script}

hostnamectl set-hostname "worker${worker_index}"

if [ ! -f "/etc/kubernetes/pki/ca.crt" ]; then
    printf "%s" "${kubeadm_join_command}" | sudo bash

    mkdir -p "/home/${ansible_user}/.kube"
    echo "${kubeconfig_content}" | sudo tee "/home/${ansible_user}/.kube/config" >/dev/null
    sudo chmod 0600 "/home/${ansible_user}/.kube/config"
    sudo chown ${ansible_user}:${ansible_user} "/home/${ansible_user}/.kube/config"
else
    echo "Worker node appears to have already joined the cluster (ca.crt exists)."
fi