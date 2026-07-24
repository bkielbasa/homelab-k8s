# Infrastructure Review Findings

Review of the homelab-k8s Terraform-managed Kubernetes cluster. Focus areas: code structure, standardization, security, and operational clarity.


## 2. Namespace Ownership Is Ambiguous

Two competing patterns for namespace creation:

- **Pattern A:** `kubernetes_namespace` resource (authentik, argocd, darek, mariadb, jellyfin)
- **Pattern B:** `create_namespace = true` on helm_release (vault, valkey, postgresql, external-secrets)

This creates confusion about who owns the namespace. Pick one. Since Linkerd injection annotations require explicit namespace config, Pattern A gives more control.

---

## 3. Code Duplication in Vault/ExternalSecrets Glue

`darek-vault.tf` and `freshrss-vault.tf` are near-identical: SecretStore + ExternalSecret + Vault policy + K8s auth role. This is ~100 lines repeated per service.

Extract a reusable module:

```hcl
# modules/service-vault/main.tf
variable services {
  type = map(object({
    namespace    = string
    sa_name      = string
    vault_path   = string
    secret_keys  = list(string)
  }))
}
```

---

## 4. Inconsistent Chart Version Pinning

Some charts pin exact versions, others float:

| Chart | Version |
|---|---|
| authentik | `2026.2.2` (pinned) |
| argocd | `9.6.0` (pinned) |
| nginx-ingress | `4.7.1` (pinned) |
| loki | **no version** |
| mariadb | **no version** |

Floating versions mean `terraform apply` can pull breaking changes. Pin everything.

---

## 5. Mixed Deployment Strategies With No Clear Boundary

Three deployment patterns running simultaneously:

- **Terraform-managed Helm** (vault, nginx, monitoring, authentik)
- **ArgoCD-managed custom charts** (freshrss, darek)
- **Raw YAML manifests** in root (cluster-issuer.yaml, coredns.yaml, storage-class.yaml)

The boundary isn't documented. The root YAMLs require manual `kubectl apply` but this isn't stated anywhere.

Suggestion: establish a clear rule, e.g. "Everything goes through Terraform or ArgoCD, nothing is kubectl-applied."

---

## 6. Scattered File Organization

Root directory has 36 `.tf` files, 6 loose `.yaml` manifests, 2 shell scripts, and a `values/` directory. Suggested structure:

```
terraform/
  infrastructure/     # nginx, cert-manager, linkerd, storage
  services/           # jellyfin, freshrss, darek, vaultwarden
  auth/               # authentik, oidc configs
  vault/              # vault, external-secrets, policies
helm/
  freshrss/
  darek/
  sentinel-sre/
values/
scripts/
  psql_create_db.sh
  psql_drop_db.sh
```

---

## 7. ArgoCD Apps Are Orphaned

The `argocd-apps/*.yaml` manifests aren't managed by Terraform or any automated process. Someone has to `kubectl apply` them manually.

Options:
- Add `kubectl_manifest` resources in Terraform to apply them
- Use ArgoCD ApplicationSet to self-manage from a directory

---

## 8. Security: Hardcoded Default for Public IP

`variables.tf` has `public_ip` with a hardcoded default:

```hcl
variable public_ip {
  type    = string
  default = "212.87.243.126"
}
```

Public IPs shouldn't be defaults. Move this to `terraform.tfvars` or a data source.

---

## 9. Operational Scripts in Root

`psql_create_db.sh` and `psql_drop_db.sh` are utility scripts that don't belong in the Terraform root. Move them to `scripts/`.

---

## 10. Vault TLS Disabled

`values/vault.yaml` has `tls_disable = 1` on the Vault listener. Even behind nginx, traffic between nginx and Vault pods travels unencrypted on the cluster network.

If Linkerd mTLS covers this, document it. Otherwise, enable TLS.

---

## 11. Linkerd Monitoring Duplication

`linkerd.tf` defines both:
- `linkerd_proxy_servicemonitor` (in monitoring.tf, lines 64-113)
- `linkerd_proxy_podmonitor` (in linkerd.tf, lines 106-155)

These target the same metrics and are likely redundant. Verify and remove one.

---

## 12. Missing README Sections

- **No `terraform.tfvars.example`** — new contributors don't know what variables are needed
- **No architecture diagram** — the relationship between Vault, Authentik, External Secrets, and apps is complex enough to warrant one
- **No documented workflow for adding services** — the skill file exists but isn't referenced in README

---

## Priority Order

| Priority | Task | Effort |
|---|---|---|
| 1 | Add state locking | 5 min |
| 2 | Pin all chart versions | 10 min |
| 3 | Extract Vault/ESO module | 1 hour |
| 4 | Document deployment boundary | 30 min |
| 5 | Reorganize file structure | 2 hours |
