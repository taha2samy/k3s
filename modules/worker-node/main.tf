resource "aws_launch_template" "worker_lt" {
  name_prefix   = "${var.cluster_name}-worker-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile {
    name = var.instance_profile_name
  }

  user_data = base64encode(templatefile("${path.module}/templates/worker-cloud-init.sh.tpl", {
    common_prereqs_script = file("${path.root}/scripts/common-k8s-prereqs.sh.tpl"),
    kubeadm_join_command  = var.kubeadm_join_command,
    kubeconfig_content    = var.kubeconfig_content,
    ansible_user          = var.ansible_user
  }))

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    instance_metadata_tags      = "enabled"
    http_put_response_hop_limit = 2
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "worker_asg" {
  name                = "${var.cluster_name}-worker-asg"
  vpc_zone_identifier = var.subnet_ids
  desired_capacity    = var.desired_worker_count
  min_size            = var.min_worker_count
  max_size            = var.max_worker_count
  launch_template {
    id      = aws_launch_template.worker_lt.id
    version = "$Latest"
  }
  health_check_type         = "EC2"
  health_check_grace_period = 30
  tag {
    key                 = "Name"
    value               = "${var.cluster_name}-worker"
    propagate_at_launch = true
  }

}