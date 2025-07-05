resource "aws_instance" "worker" {
  count         = var.worker_count
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id     = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = [var.security_group_id]

  user_data = templatefile("${path.module}/templates/worker-cloud-init.sh.tpl", {
    common_prereqs_script = file("${path.root}/scripts/common-k8s-prereqs.sh.tpl"),
    worker_index          = count.index + 1,
    kubeadm_join_command  = var.kubeadm_join_command,
    kubeconfig_content    = var.kubeconfig_content,
    ansible_user          = var.ansible_user
  })

  tags = {
    Name = "${var.cluster_name}-worker-${count.index + 1}"
  }
}

resource "null_resource" "label_workers" {
  depends_on = [aws_instance.worker]

  connection {
    type        = "ssh"
    host        = var.master_public_ip
    user        = var.ansible_user
    private_key = file(var.private_key_path)
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "timeout 300 bash -c 'while [ ! -f /home/${var.ansible_user}/.kube/config ] || [ ! -r /home/${var.ansible_user}/.kube/config ]; do sleep 5; done'",
      "timeout 300 bash -c 'while ! kubectl --kubeconfig=/home/${var.ansible_user}/.kube/config get nodes worker${count.index + 1} -o jsonpath=\"{.status.conditions[?(@.type==''Ready'')].status}\" | grep -q \"True\"; do sleep 10; done'",
      "kubectl --kubeconfig=/home/${var.ansible_user}/.kube/config label node worker${count.index + 1} node-role.kubernetes.io/worker=worker --overwrite=true",
    ]
  }

  count = var.worker_count
}