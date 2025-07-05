output "master_public_ip" {
  description = "Public IP of the Kubernetes Master node."
  value       = module.master_node.master_public_ip
}

output "worker_public_ips" {
  description = "Public IPs of the Kubernetes Worker nodes."
  value       = module.worker_nodes.worker_public_ips
}

output "kubeconfig_instructions" {
  description = "Instructions to configure kubectl on your local machine."
  value       = "To connect to your cluster, run: export KUBECONFIG=./kubeconfig-master.conf"
}