


module "ecr" {
  source       = "./modules/ecr"
  cluster_name = var.cluster_name
  
}

resource "local_file" "ecr_secret_file" {
  content  = module.ecr.config_ecr_secret_file
  depends_on = [module.ecr]
  filename = "${path.module}/ecr-image-pull-secret.json"
}




resource "aws_iam_policy" "ecr_access_policy" {
  name        = "${var.cluster_name}-ECR-Access-Policy"
  description = "Allows EC2 instances to access ECR for pulling images"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetAuthorizationToken", #
          "ecr:ListImages"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "ec2_k8s_role" {
  name = "${var.cluster_name}-EC2-K8s-Role"


  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "ecr_policy_attachment" {
  role       = aws_iam_role.ec2_k8s_role.name
  policy_arn = aws_iam_policy.ecr_access_policy.arn
}


resource "aws_iam_instance_profile" "k8s_instance_profile" {
  name = "${var.cluster_name}-Instance-Profile"
  role = aws_iam_role.ec2_k8s_role.name
}