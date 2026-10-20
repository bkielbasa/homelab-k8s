---
name: add-cluster-service
description: Use when adding a new service or app to this homelab k8s cluster — covers the Terraform files for the Helm deploy, split-horizon DNS (OVH public + Pi-hole local), Authentik OIDC SSO, Vault + External Secrets, and the Argo CD Application.
---

# Add a service to the homelab cluster

Every internet-reachable, SSO-gated service follows the same pattern:
Terraform creates the namespace/DNS/OIDC/Vault glue, Argo CD deploys the
workload from `argocd-apps/`.
`<svc>` = resource/file slug (e.g. `argocd`), `<host>` = subdomain (e.g. `argo`).
Use an existing service as a copy template: **mariadb** (upstream chart) or
**darek** (local chart + Vault secrets).

## Files to create (per service)

| File | Purpose |
|------|---------|
| `<svc>.tf` | namespace only — **no `helm_release`**: the workload is deployed by Argo CD |
| `argocd-apps/<svc>.yaml` | Argo CD Application (auto-applied by the `homelab-apps` root app on push) |
| `values/<svc>.yaml` | chart values: ingress, TLS, OIDC, app config |
| `<svc>-oidc.tf` | Authentik group + provider + application (+ policy gate) |
| `<svc>-vault.tf` | SA + Vault policy/role + External Secrets (only if it has secrets) |
| edit `ovh_domain.tf` | **public** DNS A-record |
| edit `pihole.tf` | **local** DNS record |

## CRITICAL gotchas (these have bitten us)

1. **DNS is split-horizon — add the host in BOTH files.** On the LAN, Pi-hole is
   authoritative for klimczak.xyz and returns the internal LB `192.168.1.30`; the OVH
   record (`var.public_ip`) only serves the public internet. Missing the Pi-hole record =
   "host doesn't resolve" on the LAN even when the cluster is perfectly healthy. Grep to
   confirm parity: every `ovh_domain_zone_record` needs a matching `pihole_dns_record`.
2. **Never let a `helm_release` and an Argo Application manage the same
   workload** — they will fight (selfHeal vs helm upgrade). The only remaining
   `helm_release`s are the bootstrap infra in `terraform/infrastructure`,
   `terraform/vault`, and `terraform/auth`. Also: `terraform apply -target=...`
   does NOT deploy the workload — Argo deploys from git after you push
   `argocd-apps/<svc>.yaml` to `master`.
3. **The ExternalSecret/SecretStore must exist before Argo first syncs the
   app**, or the pod starts without its Secret. Create the `<svc>-vault.tf`
   glue and push the Application in the same change (see `headlamp-vault.tf`
   for a chart that reads an existing Secret via `envFrom`/`existingSecret`).

## Shared resources (already exist — reference, don't recreate)

- OIDC data sources + custom `groups` scope mapping: `vault-oidc.tf`
- Vault k8s auth backend: `vault_auth_backend.kubernetes`
- External Secrets operator: `helm_release.external-secrets`
- Ingress: class `nginx`, LB `192.168.1.30`; cert issuer `letsencrypt-prod-dns`
- Hosts: `authentik.klimczak.xyz`, `vault.klimczak.xyz`

## 1. DNS (both records)

```hcl
# ovh_domain.tf  — public
resource "ovh_domain_zone_record" "<svc>" {
  zone = "klimczak.xyz"; subdomain = "<host>"; fieldtype = "A"; ttl = 3600
  target = var.public_ip
}
# pihole.tf  — local LAN
resource "pihole_dns_record" "<svc>" {
  domain = "<host>.klimczak.xyz"; ip = "192.168.1.30"
}
```

## 2. Authentik OIDC (`<svc>-oidc.tf`)

Copy `grafana-oidc.tf` (gate optional) or `k8s-oidc.tf` (group-gated). Key points:
`client_id = "<svc>"`; reuse shared flows/cert/scopes; `property_mappings = concat(
data.authentik_property_mapping_provider_scope.scopes.ids,
[authentik_property_mapping_provider_scope.groups.id])` to emit the `groups` claim;
`authentik_application` slug `<svc>` → issuer `https://authentik.klimczak.xyz/application/o/<svc>/`;
add `authentik_policy_binding` + an `authentik_group` to restrict who can log in.
The OIDC **client secret goes to Vault** (`vault_kv_secret_v2` in
`terraform/auth/oidc-secrets.tf`), never into chart values — the app root
reads it back through the ExternalSecret glue (`<svc>-vault.tf`). Groups are
managed manually in the Authentik UI.

## 3. Vault + External Secrets (`<svc>-vault.tf`, if the app needs secrets)

Store secrets in Vault under `secret/<app>/<name>` first. Then copy `darek.tf`:
`kubernetes_service_account` → `vault_policy` (read `secret/data/<app>/*` +
`secret/metadata/<app>/*`) → `vault_kubernetes_auth_backend_role` (bound to the SA/ns) →
`SecretStore` named `vault-backend` → `ExternalSecret`s (`dataFrom.extract` for whole
keys; a templated `kubernetes.io/dockerconfigjson` for private ghcr.io pulls). The chart's
ServiceAccount must match the bound SA name.

## 4. Namespace (`<svc>.tf`)

```hcl
resource "kubernetes_namespace" "<svc>" {
  metadata {
    name = "<svc>"
    # add: annotations = { "linkerd.io/inject" = "enabled" } if the app should be meshed
  }
}
```

There is **no `helm_release` block** — the chart is deployed by Argo CD.

`values/<svc>.yaml` ingress block: `ingressClassName: nginx`, annotations
`cert-manager.io/cluster-issuer: "letsencrypt-prod-dns"` +
`nginx.ingress.kubernetes.io/ssl-redirect: "true"`, host `<host>.klimczak.xyz`, TLS enabled.

## 5. Argo CD Application (`argocd-apps/<svc>.yaml`)

The workload's single source of truth. Files in `argocd-apps/` are applied
automatically by the `homelab-apps` root app (an app-of-apps tracking that
directory) — **pushing to `master` deploys**; no `kubectl apply`, no Terraform
step. `terraform apply` only creates the namespace/DNS/OIDC/Vault glue.

Local chart (`helm/<svc>`) — use multi-source with a `$values` ref so the
root-level values file can be referenced from outside the chart directory:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: <svc>
  namespace: argocd
spec:
  project: default
  destination:
    server: https://kubernetes.default.svc
    namespace: <svc>
  sources:
    - repoURL: https://github.com/bkielbasa/homelab-k8s
      targetRevision: master
      path: helm/<svc>
      helm:
        valueFiles:
          - $values/values/<svc>.yaml
    - repoURL: https://github.com/bkielbasa/homelab-k8s
      targetRevision: master
      ref: values
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Upstream chart — first source is the chart repo instead of a path (pin
`targetRevision` to the chart version; app name must equal the old release
name if adopting an existing install):

```yaml
  sources:
    - repoURL: https://charts.bitnami.com/bitnami   # helm repo index URL
      chart: <chart>
      targetRevision: <pinned-chart-version>
      helm:
        valueFiles:
          - $values/values/<svc>.yaml
    - repoURL: https://github.com/bkielbasa/homelab-k8s
      targetRevision: master
      ref: values
```

Add `syncOptions: [CreateNamespace=true]` only when the namespace is NOT
created by Terraform (e.g. `monitoring`). Secrets never go in values files —
see `<svc>-vault.tf` (headlamp: `envFrom`, actualbudget: `existingSecret`,
grafana: `envFromSecrets`).

## Verify (after apply)

```
dig +short <host>.klimczak.xyz                       # → 192.168.1.30 (local)
kubectl --kubeconfig ~/.kube/malinka get pods,ingress,certificate -n <svc>
curl -s -o /dev/null -w "%{http_code} %{ssl_verify_result}\n" https://<host>.klimczak.xyz/
curl -s -o /dev/null -w "%{http_code}\n" https://authentik.klimczak.xyz/application/o/<svc>/.well-known/openid-configuration
```
Cert issuer should be Let's Encrypt; `ssl_verify_result` 0; OIDC well-known 200.
For SSO-gated apps, add your user to the `<svc>-admins` Authentik group before logging in.
