resource "aws_ecr_repository" "app_repo" {
  name                 = "${var.cluster_name}-app-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

data "aws_ecr_authorization_token" "token" {
  depends_on = [aws_ecr_repository.app_repo]
}

locals {
  docker_config_json = jsonencode({
    auths = {
      (data.aws_ecr_authorization_token.token.proxy_endpoint) = {
        auth = data.aws_ecr_authorization_token.token.authorization_token
      }
    }
  })
}
