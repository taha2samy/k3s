output "worker_public_ips" {
  description = "The public IP addresses of the Kubernetes worker nodes."
  value       = aws_instance.worker.*.public_ip
}