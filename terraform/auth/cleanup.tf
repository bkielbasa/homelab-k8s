removed {
  from = kubectl_manifest.authentik_vault_secret_store
  lifecycle {
    destroy = false
  }
}

removed {
  from = kubectl_manifest.authentik_app_external_secret
  lifecycle {
    destroy = false
  }
}

removed {
  from = kubectl_manifest.authentik_postgres_external_secret
  lifecycle {
    destroy = false
  }
}

import {
  to = kubernetes_manifest.authentik_vault_secret_store
  id = "apiVersion=external-secrets.io/v1,kind=SecretStore,namespace=authentik,name=vault-backend"
}

import {
  to = kubernetes_manifest.authentik_app_external_secret
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=authentik,name=authentik-app"
}

import {
  to = kubernetes_manifest.authentik_postgres_external_secret
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=authentik,name=authentik-postgres"
}
