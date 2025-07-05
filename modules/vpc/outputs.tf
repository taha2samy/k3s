output "vpc_id" {
  description = "The ID of the created VPC."
  value       = aws_vpc.kubernetes_vpc.id
}

output "public_subnet_ids" {
  description = "A list of public subnet IDs."
  value       = aws_subnet.public.*.id
}

output "master_sg_id" {
  description = "The ID of the security group for master nodes."
  value       = aws_security_group.kubernetes_master_sg.id
}

output "worker_sg_id" {
  description = "The ID of the security group for worker nodes."
  value       = aws_security_group.kubernetes_worker_sg.id
}