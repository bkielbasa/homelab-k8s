#!/usr/bin/env bash
# State migration script: moves all Terraform state entries from the flat root
# structure into the new module hierarchy.
#
# Run ONCE after:
#   1. Old root .tf files have been removed
#   2. New terraform/*/  modules are in place
#   3. `terraform init` succeeds on the new structure
#
# Resources that STAY in the root (no mv needed):
#   - vault_auth_backend.kubernetes              (stays in root provider.tf)
#   - vault_kubernetes_auth_backend_config.kubernetes (stays in root provider.tf)
#   - data.* sources                             (re-read each plan, no state)
#   - ovh_domain_name.klimczak                  (in main.tf)
#   - ovh_domain_zone_record.root               (in main.tf)
#   - ovh_domain_zone_record.netbird            (in main.tf)
#   - pihole_dns_record.klimczak                (in main.tf)
#   - pihole_dns_record.netbird                 (in main.tf)

set -euo pipefail
cd "$(dirname "$0")/.."

tf() { terraform state mv "$1" "$2"; }

echo "=== module.vault ==="
tf helm_release.vault                                module.vault.helm_release.vault
tf helm_release.external-secrets                     module.vault.helm_release.external_secrets
tf kubernetes_namespace.vault                        module.vault.kubernetes_namespace.vault
tf kubernetes_namespace.external_secrets             module.vault.kubernetes_namespace.external_secrets
tf kubernetes_secret.vault_unseal_aws                module.vault.kubernetes_secret.vault_unseal_aws
tf aws_kms_key.vault_unseal                          module.vault.aws_kms_key.vault_unseal
tf aws_kms_alias.vault_unseal                        module.vault.aws_kms_alias.vault_unseal
tf aws_iam_user.vault_unseal                         module.vault.aws_iam_user.vault_unseal
tf aws_iam_user_policy.vault_unseal                  module.vault.aws_iam_user_policy.vault_unseal
tf aws_iam_access_key.vault_unseal                   module.vault.aws_iam_access_key.vault_unseal
tf vault_policy.vault_admin                          module.vault.vault_policy.vault_admin
tf vault_jwt_auth_backend.oidc                       module.vault.vault_jwt_auth_backend.oidc
tf vault_jwt_auth_backend_role.default               module.vault.vault_jwt_auth_backend_role.default
tf ovh_domain_zone_record.vault                      module.vault.ovh_domain_zone_record.vault
tf pihole_dns_record.vault                           module.vault.pihole_dns_record.vault

echo "=== module.auth ==="
tf authentik_property_mapping_provider_scope.groups  module.auth.authentik_property_mapping_provider_scope.groups
tf authentik_group.vault_admins                      module.auth.authentik_group.vault_admins
tf authentik_provider_oauth2.vault                   module.auth.authentik_provider_oauth2.vault
tf authentik_application.vault                       module.auth.authentik_application.vault
tf authentik_group.argocd_admins                     module.auth.authentik_group.argocd_admins
tf authentik_provider_oauth2.argocd                  module.auth.authentik_provider_oauth2.argocd
tf authentik_application.argocd                      module.auth.authentik_application.argocd
tf authentik_policy_binding.argocd_admins_required   module.auth.authentik_policy_binding.argocd_admins_required
tf authentik_group.grafana_admins                    module.auth.authentik_group.grafana_admins
tf authentik_provider_oauth2.grafana                 module.auth.authentik_provider_oauth2.grafana
tf authentik_application.grafana                     module.auth.authentik_application.grafana
tf authentik_group.kubernetes_admins                 module.auth.authentik_group.kubernetes_admins
tf authentik_provider_oauth2.kubernetes              module.auth.authentik_provider_oauth2.kubernetes
tf authentik_application.kubernetes                  module.auth.authentik_application.kubernetes
tf authentik_policy_binding.kubernetes_admins_required module.auth.authentik_policy_binding.kubernetes_admins_required
tf kubernetes_cluster_role_binding.oidc_kubernetes_admins module.auth.kubernetes_cluster_role_binding.oidc_kubernetes_admins
# Authentik helm + vault wiring
tf kubernetes_namespace.authentik                    module.auth.kubernetes_namespace.authentik
tf helm_release.authentik                            module.auth.helm_release.authentik
tf kubernetes_service_account.authentik              module.auth.kubernetes_service_account.authentik
tf vault_policy.authentik                            module.auth.vault_policy.authentik
tf vault_kubernetes_auth_backend_role.authentik      module.auth.vault_kubernetes_auth_backend_role.authentik
tf kubectl_manifest.authentik_vault_secret_store     module.auth.kubectl_manifest.authentik_vault_secret_store
tf kubectl_manifest.authentik_app_external_secret    module.auth.kubectl_manifest.authentik_app_external_secret
tf kubectl_manifest.authentik_postgres_external_secret module.auth.kubectl_manifest.authentik_postgres_external_secret
tf ovh_domain_zone_record.authentik                  module.auth.ovh_domain_zone_record.authentik
tf pihole_dns_record.authentik                       module.auth.pihole_dns_record.authentik
# Per-service OIDC providers (Authentik resources)
tf authentik_group.jellyfin_users                    module.auth.authentik_group.jellyfin_users
tf authentik_group.jellyfin_admins                   module.auth.authentik_group.jellyfin_admins
tf authentik_provider_oauth2.jellyfin                module.auth.authentik_provider_oauth2.jellyfin
tf authentik_application.jellyfin                    module.auth.authentik_application.jellyfin
tf authentik_group.actualbudget_users                module.auth.authentik_group.actualbudget_users
tf authentik_provider_oauth2.actualbudget            module.auth.authentik_provider_oauth2.actualbudget
tf authentik_application.actualbudget                module.auth.authentik_application.actualbudget
tf authentik_group.darek_users                       module.auth.authentik_group.darek_users
tf authentik_provider_oauth2.darek                   module.auth.authentik_provider_oauth2.darek
tf authentik_application.darek                       module.auth.authentik_application.darek
tf authentik_group.freshrss_users                    module.auth.authentik_group.freshrss_users
tf authentik_provider_oauth2.freshrss                module.auth.authentik_provider_oauth2.freshrss
tf authentik_application.freshrss                    module.auth.authentik_application.freshrss
tf authentik_group.navidrome_users                   module.auth.authentik_group.navidrome_users
tf authentik_provider_oauth2.navidrome               module.auth.authentik_provider_oauth2.navidrome
tf authentik_application.navidrome                   module.auth.authentik_application.navidrome
tf authentik_policy_binding.navidrome_users_required module.auth.authentik_policy_binding.navidrome_users_required

echo "=== module.infrastructure ==="
tf kubernetes_namespace.metallb                      module.infrastructure.kubernetes_namespace.metallb
tf helm_release.metallb                              module.infrastructure.helm_release.metallb
tf kubernetes_manifest.metallb_ip_pool               module.infrastructure.kubernetes_manifest.metallb_ip_pool
tf kubernetes_manifest.metallb_l2_adv               module.infrastructure.kubernetes_manifest.metallb_l2_adv
tf kubernetes_namespace.ingress_nginx                module.infrastructure.kubernetes_namespace.ingress_nginx
tf helm_release.nginx_ingress                        module.infrastructure.helm_release.nginx_ingress
tf kubernetes_secret.ovh_credentials                 module.infrastructure.kubernetes_secret.ovh_credentials
tf helm_release.cert_manager_webhook_ovh             module.infrastructure.helm_release.cert_manager_webhook_ovh
tf tls_private_key.trustanchor_key                   module.infrastructure.tls_private_key.trustanchor_key
tf tls_self_signed_cert.trustanchor_cert             module.infrastructure.tls_self_signed_cert.trustanchor_cert
tf tls_private_key.issuer_key                        module.infrastructure.tls_private_key.issuer_key
tf tls_cert_request.issuer_req                       module.infrastructure.tls_cert_request.issuer_req
tf tls_locally_signed_cert.issuer_cert               module.infrastructure.tls_locally_signed_cert.issuer_cert
tf kubernetes_namespace.linkerd                      module.infrastructure.kubernetes_namespace.linkerd
tf helm_release.linkerd_crds                         module.infrastructure.helm_release.linkerd_crds
tf helm_release.linkerd_control_plane                module.infrastructure.helm_release.linkerd_control_plane
tf kubernetes_namespace.linkerd_viz                  module.infrastructure.kubernetes_namespace.linkerd_viz
tf helm_release.linkerd_viz                          module.infrastructure.helm_release.linkerd_viz
tf kubernetes_manifest.linkerd_proxy_podmonitor      module.infrastructure.kubernetes_manifest.linkerd_proxy_podmonitor
tf kubernetes_manifest.linkerd_control_plane_podmonitor module.infrastructure.kubernetes_manifest.linkerd_control_plane_podmonitor
tf kubernetes_storage_class_v1.qnap_nfs              module.infrastructure.kubernetes_storage_class_v1.qnap_nfs
tf kubernetes_namespace.argocd                       module.infrastructure.kubernetes_namespace.argocd
tf helm_release.argocd                               module.infrastructure.helm_release.argocd
tf ovh_domain_zone_record.argocd                     module.infrastructure.ovh_domain_zone_record.argocd
tf pihole_dns_record.argocd                          module.infrastructure.pihole_dns_record.argocd

echo "=== module.monitoring ==="
tf helm_release.prometheus                           module.monitoring.helm_release.prometheus
tf helm_release.loki                                 module.monitoring.helm_release.loki
tf helm_release.alloy                                module.monitoring.helm_release.alloy
tf helm_release.tempo                                module.monitoring.helm_release.tempo
tf kubernetes_manifest.linkerd_proxy_servicemonitor  module.monitoring.kubernetes_manifest.linkerd_proxy_servicemonitor
# Note: only pihole record exists for grafana in state; no OVH record was ever created
tf pihole_dns_record.grafana                         module.monitoring.pihole_dns_record.grafana

echo "=== module.services ==="
tf kubernetes_namespace.jellyfin                     module.services.kubernetes_namespace.jellyfin
tf helm_release.jellyfin                             module.services.helm_release.jellyfin
tf ovh_domain_zone_record.jellyfin                   module.services.ovh_domain_zone_record.jellyfin
tf pihole_dns_record.jellyfin                        module.services.pihole_dns_record.jellyfin
tf kubernetes_namespace.actualbudget                 module.services.kubernetes_namespace.actualbudget
tf helm_release.actualbudget                         module.services.helm_release.actualbudget
# Note: no ovh_domain_zone_record.actualbudget in state — will be created fresh
tf pihole_dns_record.budget-board                    module.services.pihole_dns_record.budget-board
tf kubernetes_namespace.vaultwarden                  module.services.kubernetes_namespace.vaultwarden
tf helm_release.vaultwarden                          module.services.helm_release.vaultwarden
# Note: no ovh_domain_zone_record.vaultwarden in state — will be created fresh
tf pihole_dns_record.pass                            module.services.pihole_dns_record.pass
tf kubernetes_namespace.headlamp                     module.services.kubernetes_namespace.headlamp
tf helm_release.headlamp                             module.services.helm_release.headlamp
tf ovh_domain_zone_record.headlamp                   module.services.ovh_domain_zone_record.headlamp
tf pihole_dns_record.headlamp                        module.services.pihole_dns_record.headlamp
tf kubernetes_namespace.darek                        module.services.kubernetes_namespace.darek
tf kubernetes_service_account.darek                  module.services.kubernetes_service_account.darek
tf vault_policy.darek                                module.services.vault_policy.darek
tf vault_kubernetes_auth_backend_role.darek          module.services.vault_kubernetes_auth_backend_role.darek
tf kubectl_manifest.darek_vault_secret_store         module.services.kubectl_manifest.darek_vault_secret_store
tf kubectl_manifest.darek_env_external_secret        module.services.kubectl_manifest.darek_env_external_secret
tf ovh_domain_zone_record.darek                      module.services.ovh_domain_zone_record.darek
tf pihole_dns_record.darek                           module.services.pihole_dns_record.darek
tf vault_kv_secret_v2.freshrss_oidc                  module.services.vault_kv_secret_v2.freshrss_oidc
tf vault_policy.freshrss                             module.services.vault_policy.freshrss
tf vault_kubernetes_auth_backend_role.freshrss        module.services.vault_kubernetes_auth_backend_role.freshrss
tf kubectl_manifest.freshrss_vault_secret_store      module.services.kubectl_manifest.freshrss_vault_secret_store
tf kubectl_manifest.freshrss_oidc_external_secret    module.services.kubectl_manifest.freshrss_oidc_external_secret
# Note: no ovh_domain_zone_record.freshrss exists in state
tf pihole_dns_record.freshrss                        module.services.pihole_dns_record.freshrss
tf kubernetes_namespace.sentinel                     module.services.kubernetes_namespace.sentinel
tf kubernetes_service_account.sentinel               module.services.kubernetes_service_account.sentinel
tf vault_policy.sentinel                             module.services.vault_policy.sentinel
tf vault_kubernetes_auth_backend_role.sentinel        module.services.vault_kubernetes_auth_backend_role.sentinel
tf kubectl_manifest.sentinel_vault_secret_store      module.services.kubectl_manifest.sentinel_vault_secret_store
tf kubectl_manifest.sentinel_ghcr_external_secret    module.services.kubectl_manifest.sentinel_ghcr_external_secret
tf 'kubectl_manifest.sentinel_external_secret["sentinel-anthropic"]' 'module.services.kubectl_manifest.sentinel_external_secret["sentinel-anthropic"]'
tf 'kubectl_manifest.sentinel_external_secret["sentinel-db"]'        'module.services.kubectl_manifest.sentinel_external_secret["sentinel-db"]'
tf ovh_domain_zone_record.sentinel                   module.services.ovh_domain_zone_record.sentinel
tf pihole_dns_record.sentinel                        module.services.pihole_dns_record.sentinel
tf kubernetes_namespace.navidrome                    module.services.kubernetes_namespace.navidrome
tf ovh_domain_zone_record.navidrome                  module.services.ovh_domain_zone_record.navidrome
tf pihole_dns_record.navidrome                       module.services.pihole_dns_record.navidrome
tf kubernetes_namespace.mariadb                      module.services.kubernetes_namespace.mariadb
tf helm_release.mariadb                              module.services.helm_release.mariadb
tf kubernetes_namespace.postgresql                   module.services.kubernetes_namespace.postgresql
tf helm_release.postgresql                           module.services.helm_release.postgresql
tf kubernetes_namespace.valkey                       module.services.kubernetes_namespace.valkey
tf helm_release.valkey                               module.services.helm_release.valkey

echo ""
echo "State migration complete. Run: terraform plan"
echo "Expected: 0 to add, 0 to change, 0 to destroy (modulo data sources)"
