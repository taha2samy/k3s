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

AWS_REGION=$$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
AWS_ACCOUNT_ID=$$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep accountId | awk -F\" '{print $$4}')
ECR_REGISTRY="$${AWS_ACCOUNT_ID}.dkr.ecr.$${AWS_REGION}.amazonaws.com"

ECR_SECRET_NAME="ecr-registry-secret"
DEFAULT_NAMESPACE="default"

ECR_PASSWORD=$$(aws ecr get-login-password --region "$${AWS_REGION}")

/home/${ansible_user}/.kube/config kubectl --kubeconfig=/home/${ansible_user}/.kube/config create secret docker-registry "$${ECR_SECRET_NAME}" \
  --docker-server="$${ECR_REGISTRY}" \
  --docker-username=AWS \
  --docker-password="$${ECR_PASSWORD}" \
  --namespace="$${DEFAULT_NAMESPACE}" \
  --dry-run=client -o yaml | /home/${ansible_user}/.kube/config kubectl --kubeconfig=/home/${ansible_user}/.kube/config apply -f -

/home/${ansible_user}/.kube/config kubectl --kubeconfig=/home/${ansible_user}/.kube/config patch serviceaccount default \
  -n "$${DEFAULT_NAMESPACE}" \
  -p "{\"imagePullSecrets\": [{\"name\": \"$${ECR_SECRET_NAME}\"}]}"

echo "ECR Image Pull Secret configured for the 'default' service account."
echo "Kubernetes master node setup completed."
