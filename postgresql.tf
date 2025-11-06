resource "helm_release" "postgresql" {
  name             = "postgresql"
  namespace        = "postgresql"
  chart            = "./helm/postgresql"
  create_namespace = true
} 
