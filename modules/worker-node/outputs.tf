data "aws_instances" "workers" {
  depends_on = [aws_autoscaling_group.worker_asg]

  instance_tags = {
    Name = "${var.cluster_name}-worker"
  }

  instance_state_names = ["running"]
}

output "worker_public_ips" {
  description = "The public IP addresses of the Kubernetes worker nodes. This is dynamic."
  value       = data.aws_instances.workers.public_ips
}