resource "aws_instance" "worker" {
  count         = var.worker_count
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id     = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile = var.instance_profile_name

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
    # 1. Wait for the kubeconfig file to become available and readable. This part is correct and remains.
    "timeout 300 bash -c 'while [ ! -f /home/${var.ansible_user}/.kube/config ] || [ ! -r /home/${var.ansible_user}/.kube/config ]; do echo \\\"Waiting for kubeconfig file...\\\"; sleep 5; done'",

    # 2. (THE FIX) Wait in a loop until the node is both registered (found) AND in a Ready state.
    # This loop will tolerate 'NotFound' errors and keep retrying.
    # We add a small internal timeout to 'kubectl wait' and a longer external timeout for the whole process.
    "timeout 480 bash -c 'while ! kubectl --kubeconfig=/home/${var.ansible_user}/.kube/config wait --for=condition=Ready node/worker${count.index + 1} --timeout=20s > /dev/null 2>&1; do echo \"Waiting for node worker${count.index + 1} to register and become Ready...\"; sleep 10; done'",

    # 3. Once the node is ready, label it. The output is suppressed to keep the logs clean.
    "kubectl --kubeconfig=/home/${var.ansible_user}/.kube/config label node worker${count.index + 1} node-role.kubernetes.io/worker=worker --overwrite=true > /dev/null",
  ]
}
  count = var.worker_count
}