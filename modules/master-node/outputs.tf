output "master_public_ip" {
  description = "The public IP address of the Kubernetes master node."
  value       = aws_instance.master.public_ip
}