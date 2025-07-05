variable "ami_id" {
  description = "The AMI ID for the EC2 instances."
  type        = string
}

variable "instance_type" {
  description = "The instance type for the master node."
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "The name of the SSH key pair to use."
  type        = string
}

variable "private_key_path" {
  description = "Path to the private key file for SSH access."
  type        = string
}

variable "subnet_id" {
  description = "The ID of the subnet to launch the master node in."
  type        = string
}

variable "security_group_id" {
  description = "The ID of the security group for the master node."
  type        = string
}

variable "cluster_name" {
  description = "The name of the Kubernetes cluster."
  type        = string
}

variable "ansible_user" {
  description = "The SSH user for the AMI (e.g., 'ubuntu' for Ubuntu AMIs)."
  type        = string
  default     = "ubuntu"
}