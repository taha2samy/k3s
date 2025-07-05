variable "ami_id" {
  type = string
}
variable "instance_type" {
  type = string
}
variable "key_name" {
  type = string
}
variable "subnet_ids" {
  type = list(string)
}
variable "security_group_id" {
  type = string
}
variable "instance_profile_name" {
  type = string
}
variable "cluster_name" {
  type = string
}
variable "desired_worker_count" {
  type = number
}
variable "min_worker_count" {
  type = number
}
variable "max_worker_count" {
  type = number
}
variable "kubeadm_join_command" {
  type      = string
  sensitive = true
}
variable "kubeconfig_content" {
  type      = string
  sensitive = true
}
variable "ansible_user" {
  type = string
}