---
name: add-cluster-service
description: Use when adding a new service or app to this homelab k8s cluster — covers the Terraform files for the Helm deploy, split-horizon DNS (OVH public + Pi-hole local), Authentik OIDC SSO, Vault + External Secrets, and the Argo CD Application.
---

# Add a service to the homelab cluster

Every internet-reachable, SSO-gated service follows the same set of Terraform files.
`<svc>` = resource/file slug (e.g. `argocd`), `<host>` = subdomain (e.g. `argo`).
Use an existing service as a copy template: **argocd** (upstream chart) or **sentinel**
(local chart + Vault secrets).

## Files to create (per service)

| File | Purpose |
|------|---------|
| `<svc>.tf` | namespace + `helm_release` (+ `set_sensitive`, `depends_on`) |
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
2. **`-target` only applies a resource's dependency closure.** `terraform apply
   -target=helm_release.<svc>` will NOT create the DNS records or Authentik application
   unless `helm_release.<svc>` `depends_on` them. Either add that `depends_on` (see
   `argocd.tf`) or run a full `terraform apply`.
3. **Helm releases that consume secrets must `depends_on` the ExternalSecret/SecretStore**
   so the k8s Secret exists before the Deployment rolls.

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
Inject the secret into the chart via `set_sensitive` in `<svc>.tf` (see `monitoring.tf` /
`argocd.tf`). Groups are managed manually in the Authentik UI.

## 3. Vault + External Secrets (`<svc>-vault.tf`, if the app needs secrets)

Store secrets in Vault under `secret/<app>/<name>` first. Then copy `sentinel-vault.tf`:
`kubernetes_service_account` → `vault_policy` (read `secret/data/<app>/*` +
`secret/metadata/<app>/*`) → `vault_kubernetes_auth_backend_role` (bound to the SA/ns) →
`SecretStore` named `vault-backend` → `ExternalSecret`s (`dataFrom.extract` for whole
keys; a templated `kubernetes.io/dockerconfigjson` for private ghcr.io pulls). The chart's
ServiceAccount must match the bound SA name.

## 4. Helm release (`<svc>.tf`)

```hcl
resource "kubernetes_namespace" "<svc>" { metadata { name = "<svc>" } }

resource "helm_release" "<svc>" {
  name      = "<svc>"
  namespace = kubernetes_namespace.<svc>.metadata[0].name
  # upstream: repository + chart + version ; local: chart = "./helm/<svc>"
  repository = "https://..."; chart = "..."; version = "x.y.z"
  values = [file("values/<svc>.yaml")]

  set_sensitive = [{ name = "<oidc.secret.path>", value = authentik_provider_oauth2.<svc>.client_secret }]

  depends_on = [  # so -target pulls everything; drop entries that don't apply
    authentik_application.<svc>,
    ovh_domain_zone_record.<svc>,
    pihole_dns_record.<svc>,
    kubectl_manifest.<svc>_external_secret,
  ]
}
```

`values/<svc>.yaml` ingress block: `ingressClassName: nginx`, annotations
`cert-manager.io/cluster-issuer: "letsencrypt-prod-dns"` +
`nginx.ingress.kubernetes.io/ssl-redirect: "true"`, host `<host>.klimczak.xyz`, TLS enabled.

## 5. Argo CD Application (GitOps deploy)

Once a chart lives in this repo (`helm/<svc>`), register it with Argo instead of (or in
addition to) the Terraform helm_release — but don't let both manage the same workload.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: { name: <svc>, namespace: argocd }
spec:
  project: default
  source:
    repoURL: https://github.com/bkielbasa/homelab-k8s
    path: helm/<svc>
    targetRevision: master
    helm: { valueFiles: [values.yaml] }
  destination: { server: https://kubernetes.default.svc, namespace: <svc> }
  syncPolicy: { automated: { prune: true, selfHeal: true } }
```

## Verify (after apply)

```
dig +short <host>.klimczak.xyz                       # → 192.168.1.30 (local)
kubectl --kubeconfig ~/.kube/malinka get pods,ingress,certificate -n <svc>
curl -s -o /dev/null -w "%{http_code} %{ssl_verify_result}\n" https://<host>.klimczak.xyz/
curl -s -o /dev/null -w "%{http_code}\n" https://authentik.klimczak.xyz/application/o/<svc>/.well-known/openid-configuration
```
Cert issuer should be Let's Encrypt; `ssl_verify_result` 0; OIDC well-known 200.
For SSO-gated apps, add your user to the `<svc>-admins` Authentik group before logging in.
