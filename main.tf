terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "tls_private_key" "k8s_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "${var.cluster_name}-ssh-key"
  public_key = tls_private_key.k8s_key.public_key_openssh
}

resource "local_file" "k8s_private_key_file" {
  content  = tls_private_key.k8s_key.private_key_pem
  filename = "${path.module}/${var.cluster_name}-ssh-key.pem"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

module "vpc" {
  source       = "./modules/vpc"
  cluster_name = var.cluster_name
}

module "master_node" {
  source           = "./modules/master-node"
  ami_id           = data.aws_ami.ubuntu.id
  instance_type    = var.master_instance_type
  key_name         = aws_key_pair.generated_key.key_name
  private_key_path = local_file.k8s_private_key_file.filename
  subnet_id        = module.vpc.public_subnet_ids[0]
  security_group_id = module.vpc.master_sg_id
  cluster_name     = var.cluster_name
  ansible_user     = var.ssh_user
}

resource "null_resource" "set_private_key_permissions" {
  depends_on = [local_file.k8s_private_key_file]

  provisioner "local-exec" {
    command = "chmod 400 ${local_file.k8s_private_key_file.filename}"
    working_dir = "${path.module}"
  }
}

data "local_file" "kubeadm_join_command_file" {
  depends_on = [module.master_node.master_setup]
  filename   = "${path.module}/kubeadm_join_command"
}

data "local_file" "kubeconfig_master_file" {
  depends_on = [module.master_node.master_setup]
  filename   = "${path.module}/kubeconfig-master.conf"
}

module "worker_nodes" {
  source           = "./modules/worker-node"
  depends_on       = [module.master_node.master_setup, null_resource.set_private_key_permissions]
  ami_id           = data.aws_ami.ubuntu.id
  instance_type    = var.worker_instance_type
  key_name         = aws_key_pair.generated_key.key_name
  private_key_path = local_file.k8s_private_key_file.filename
  subnet_ids       = module.vpc.public_subnet_ids
  security_group_id = module.vpc.worker_sg_id
  worker_count     = var.worker_count
  cluster_name     = var.cluster_name
  kubeadm_join_command = data.local_file.kubeadm_join_command_file.content
  kubeconfig_content   = data.local_file.kubeconfig_master_file.content
  master_public_ip     = module.master_node.master_public_ip
  ansible_user         = var.ssh_user
}

