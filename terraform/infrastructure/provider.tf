# No config_path: when run in-cluster (infra-guy worker) the provider uses the
# pod service account; locally it falls back to KUBECONFIG.
provider "kubernetes" {}

# Kept only so removed blocks below can resolve during state cleanup.
provider "kubectl" {
  host                   = "https://kubernetes.default.svc"
  cluster_ca_certificate = file("/var/run/secrets/kubernetes.io/serviceaccount/ca.crt")
  token                  = file("/var/run/secrets/kubernetes.io/serviceaccount/token")
}


provider "helm" {
  kubernetes = {}
}

provider "vault" {
  address = var.vault_addr
  token   = var.vault_token
}

# infra-guy should inject these via project variables / secrets:
#   TF_VAR_vault_token, TF_VAR_ovh_app_key, TF_VAR_ovh_app_secret,
#   TF_VAR_ovh_consumer_key, TF_VAR_pihole_password

provider "ovh" {
  endpoint           = "ovh-eu"
  application_key    = var.ovh_app_key
  application_secret = var.ovh_app_secret
  consumer_key       = var.ovh_consumer_key
}

provider "pihole" {
  url      = "http://192.168.1.29:8081"
  password = var.pihole_password
}

provider "tls" {}
