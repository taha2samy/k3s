output "config_ecr_secret_file" {
  value = local.docker_config_json
  
}
output "aws_ecr_repository" {
    value = aws_ecr_repository.app_repo.repository_url
  
}