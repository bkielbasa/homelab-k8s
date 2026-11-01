# Temporary: drop old kubectl_manifest state entries without destroying.
removed {
  from = kubectl_manifest.actualbudget_vault_secret_store
  lifecycle {
    destroy = false
  }
}
removed {
  from = kubectl_manifest.actualbudget_oidc_external_secret
  lifecycle {
    destroy = false
  }
}
removed {
  from = kubectl_manifest.darek_vault_secret_store
  lifecycle {
    destroy = false
  }
}
removed {
  from = kubectl_manifest.darek_env_external_secret
  lifecycle {
    destroy = false
  }
}
removed {
  from = kubectl_manifest.ecommerce_vault_secret_store
  lifecycle {
    destroy = false
  }
}
removed {
  from = kubectl_manifest.ecommerce_db_external_secret
  lifecycle {
    destroy = false
  }
}
removed {
  from = kubectl_manifest.freshrss_vault_secret_store
  lifecycle {
    destroy = false
  }
}
removed {
  from = kubectl_manifest.freshrss_oidc_external_secret
  lifecycle {
    destroy = false
  }
}
removed {
  from = kubectl_manifest.headlamp_vault_secret_store
  lifecycle {
    destroy = false
  }
}
removed {
  from = kubectl_manifest.headlamp_oidc_external_secret
  lifecycle {
    destroy = false
  }
}
removed {
  from = kubectl_manifest.infra_guy_vault_secret_store
  lifecycle {
    destroy = false
  }
}
removed {
  from = kubectl_manifest.infra_guy_env_external_secret
  lifecycle {
    destroy = false
  }
}
removed {
  from = kubectl_manifest.smarthome_metrics_vault_secret_store
  lifecycle {
    destroy = false
  }
}
removed {
  from = kubectl_manifest.smarthome_metrics_db_external_secret
  lifecycle {
    destroy = false
  }
}
removed {
  from = kubectl_manifest.workspace_vault_secret_store
  lifecycle {
    destroy = false
  }
}
removed {
  from = kubectl_manifest.workspace_db_external_secret
  lifecycle {
    destroy = false
  }
}
removed {
  from = kubectl_manifest.workspace_sso_external_secret
  lifecycle {
    destroy = false
  }
}

import {
  to = kubernetes_manifest.actualbudget_vault_secret_store
  id = "apiVersion=external-secrets.io/v1,kind=SecretStore,namespace=actualbudget,name=vault-backend"
}

import {
  to = kubernetes_manifest.actualbudget_oidc_external_secret
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=actualbudget,name=actualbudget-oidc"
}

import {
  to = kubernetes_manifest.darek_vault_secret_store
  id = "apiVersion=external-secrets.io/v1,kind=SecretStore,namespace=darek,name=vault-backend"
}

import {
  to = kubernetes_manifest.darek_env_external_secret
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=darek,name=darek-env"
}

import {
  to = kubernetes_manifest.ecommerce_vault_secret_store
  id = "apiVersion=external-secrets.io/v1,kind=SecretStore,namespace=ecommerce,name=vault-backend"
}

import {
  to = kubernetes_manifest.ecommerce_db_external_secret
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=ecommerce,name=ecommerce-db"
}

import {
  to = kubernetes_manifest.freshrss_vault_secret_store
  id = "apiVersion=external-secrets.io/v1,kind=SecretStore,namespace=freshrss,name=vault-backend"
}

import {
  to = kubernetes_manifest.freshrss_oidc_external_secret
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=freshrss,name=freshrss-oidc"
}

import {
  to = kubernetes_manifest.headlamp_vault_secret_store
  id = "apiVersion=external-secrets.io/v1,kind=SecretStore,namespace=headlamp,name=vault-backend"
}

import {
  to = kubernetes_manifest.headlamp_oidc_external_secret
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=headlamp,name=headlamp-oidc"
}

import {
  to = kubernetes_manifest.infra_guy_vault_secret_store
  id = "apiVersion=external-secrets.io/v1,kind=SecretStore,namespace=infra-guy,name=vault-backend"
}

import {
  to = kubernetes_manifest.infra_guy_env_external_secret
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=infra-guy,name=infra-guy-env"
}

import {
  to = kubernetes_manifest.smarthome_metrics_vault_secret_store
  id = "apiVersion=external-secrets.io/v1,kind=SecretStore,namespace=smarthome-metrics,name=vault-backend"
}

import {
  to = kubernetes_manifest.smarthome_metrics_db_external_secret
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=smarthome-metrics,name=smarthome-metrics-db"
}

import {
  to = kubernetes_manifest.workspace_vault_secret_store
  id = "apiVersion=external-secrets.io/v1,kind=SecretStore,namespace=workspace,name=vault-backend"
}

import {
  to = kubernetes_manifest.workspace_db_external_secret
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=workspace,name=workspace-db"
}

import {
  to = kubernetes_manifest.workspace_sso_external_secret
  id = "apiVersion=external-secrets.io/v1,kind=ExternalSecret,namespace=workspace,name=workspace-sso"
}
