provider "kubernetes" {
   config_path =   data.local_file.kubeconfig_master_file.filename
}



resource "kubernetes_secret_v1" "ecr_secret" {
  metadata {
    name      = "ecr-registry-secret"
    namespace = "default" 
  }

  data = {
    ".dockerconfigjson" = local_file.ecr_secret_file.content
  }

  type = "kubernetes.io/dockerconfigjson"
}

