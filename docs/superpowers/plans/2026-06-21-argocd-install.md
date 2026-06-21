# Argo CD Install Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy Argo CD at `argo.klimczak.xyz` with Authentik SSO (direct OIDC), gated to the `argocd-admins` group as `role:admin`, with the local admin user disabled.

**Architecture:** Three new Terraform files plus one DNS record, following the existing Grafana pattern. `argocd-oidc.tf` defines the Authentik OAuth2 provider/application/group; `argocd.tf` deploys the upstream `argo-cd` Helm chart with the client secret injected via `set_sensitive`; `values/argocd.yaml` carries chart config (OIDC, RBAC, ingress, insecure server). DNS A-record added in `ovh_domain.tf`.

**Tech Stack:** Terraform (helm, kubernetes, authentik, ovh providers), Argo CD Helm chart `argo-cd` v9.6.0 (Argo CD v3.4.4), Authentik OIDC, nginx-ingress, cert-manager.

**Scope note:** This plan stops at `terraform plan`. The user runs `terraform apply` themselves. Manual post-apply verification is listed in Task 6.

**Reference files (read before starting):**
- `grafana-oidc.tf` — OAuth2 provider/application shape
- `vault-oidc.tf` — shared data sources (`default_authorization_flow`, `default_invalidation_flow`, `authentik_certificate_key_pair.default`, `property_mapping_provider_scope.scopes`, `property_mapping_provider_scope.groups`); `k8s-oidc.tf` for the `authentik_policy_binding` group-gate
- `monitoring.tf` — `helm_release` + `set_sensitive` shape
- `values/prometheus.yaml` — ingress annotations / cluster-issuer / TLS
- `ovh_domain.tf` — DNS record shape

**Commit style (repo convention):** one-line conventional-commit subject, no body, no AI co-author trailer.

---

### Task 1: Authentik OIDC provider, application, and group gate

**Files:**
- Create: `argocd-oidc.tf`

- [ ] **Step 1: Write `argocd-oidc.tf`**

```hcl
# Authentik group whose members get admin access to Argo CD.
# Membership managed manually in the Authentik UI.
resource "authentik_group" "argocd_admins" {
  name = "argocd-admins"
}

resource "authentik_provider_oauth2" "argocd" {
  name               = "argocd"
  client_id          = "argocd"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation_flow.id
  signing_key        = data.authentik_certificate_key_pair.default.id

  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://argo.klimczak.xyz/auth/callback"
    },
    # argocd CLI SSO login opens a local HTTP server on :8085.
    {
      matching_mode = "strict"
      url           = "http://localhost:8085/auth/callback"
    },
  ]

  property_mappings = concat(
    data.authentik_property_mapping_provider_scope.scopes.ids,
    [authentik_property_mapping_provider_scope.groups.id],
  )
}

resource "authentik_application" "argocd" {
  name              = "Argo CD"
  slug              = "argocd"
  protocol_provider = authentik_provider_oauth2.argocd.id
  meta_launch_url   = "https://argo.klimczak.xyz"
  meta_icon         = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons@main/png/argo-cd.png"
}

# Only members of argocd-admins may launch/authenticate to the application.
resource "authentik_policy_binding" "argocd_admins_required" {
  target = authentik_application.argocd.uuid
  group  = authentik_group.argocd_admins.id
  order  = 0
}
```

- [ ] **Step 2: Format and validate**

Run: `terraform fmt argocd-oidc.tf && terraform validate`
Expected: `argocd-oidc.tf` reformatted if needed; validate prints `Success! The configuration is valid.`

> Note: `terraform validate` requires initialized providers. If it errors about uninitialized providers, run `terraform init` first. The slug `argocd` must match the issuer URL used in Task 3 (`…/application/o/argocd/`).

- [ ] **Step 3: Commit**

```bash
git add argocd-oidc.tf
git commit -m "feat(argocd): add Authentik OIDC provider, app, and admin group gate"
```

---

### Task 2: Helm values file

**Files:**
- Create: `values/argocd.yaml`

- [ ] **Step 1: Write `values/argocd.yaml`**

```yaml
global:
  domain: argo.klimczak.xyz

configs:
  cm:
    url: https://argo.klimczak.xyz
    # Local admin disabled — Authentik SSO is the only way in.
    admin.enabled: false
    oidc.config: |
      name: Authentik
      issuer: https://authentik.klimczak.xyz/application/o/argocd/
      clientID: argocd
      clientSecret: $oidc.argocd.clientSecret
      requestedScopes:
        - openid
        - profile
        - email
        - groups

  rbac:
    # argocd-admins (Authentik group, via the groups claim) -> full admin.
    policy.csv: |
      g, argocd-admins, role:admin
    # No access for anyone outside the mapped groups.
    policy.default: ""
    scopes: "[groups]"

  params:
    # nginx terminates TLS; argocd-server serves plain HTTP behind the ingress.
    server.insecure: true

server:
  ingress:
    enabled: true
    ingressClassName: nginx
    hostname: argo.klimczak.xyz
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod-dns
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
    tls: true
```

- [ ] **Step 2: Render the chart with these values to confirm they are schema-valid**

Run:
```bash
helm template argocd argo/argo-cd --version 9.6.0 -n argocd -f values/argocd.yaml > /tmp/argocd-render.yaml; echo "exit=$status"
```
(If the `argo` repo is missing: `helm repo add argo https://argoproj.github.io/argo-helm && helm repo update argo`.)
Expected: command exits 0 and `/tmp/argocd-render.yaml` is non-empty. The chart's JSON-schema validation passes (no `values don't meet the specifications` error).

- [ ] **Step 3: Spot-check the rendered output reflects the intent**

Run:
```bash
grep -E "admin.enabled|oidc.argocd.clientSecret|policy.default|server.insecure|host: argo.klimczak.xyz" /tmp/argocd-render.yaml
```
Expected: shows `admin.enabled: "false"` in the argocd-cm ConfigMap, the `$oidc.argocd.clientSecret` reference in `oidc.config`, `policy.default` empty in argocd-rbac-cm, `server.insecure: "true"` in argocd-cmd-params-cm, and `host: argo.klimczak.xyz` in the Ingress.

- [ ] **Step 4: Commit**

```bash
git add values/argocd.yaml
git commit -m "feat(argocd): add Helm values with OIDC, RBAC, and ingress"
```

---

### Task 3: Helm release wiring

**Files:**
- Create: `argocd.tf`

- [ ] **Step 1: Write `argocd.tf`**

```hcl
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "9.6.0"

  values = [
    file("values/argocd.yaml")
  ]

  # Inject the Authentik OIDC client secret into argocd-secret. The dotted key
  # `oidc.argocd.clientSecret` is referenced by oidc.config in values/argocd.yaml;
  # dots in the key are escaped so Helm writes one key rather than nesting.
  set_sensitive = [
    {
      name  = "configs.secret.extra.oidc\\.argocd\\.clientSecret"
      value = authentik_provider_oauth2.argocd.client_secret
    },
  ]
}
```

- [ ] **Step 2: Format and validate**

Run: `terraform fmt argocd.tf && terraform validate`
Expected: validate prints `Success! The configuration is valid.`

- [ ] **Step 3: Commit**

```bash
git add argocd.tf
git commit -m "feat(argocd): deploy argo-cd Helm chart with Vault-sourced OIDC secret"
```

---

### Task 4: DNS record

**Files:**
- Modify: `ovh_domain.tf` (append a new record block after the `sentinel` record, lines ~61-67)

- [ ] **Step 1: Append the `argo` A-record to `ovh_domain.tf`**

Add at the end of the file:
```hcl
resource "ovh_domain_zone_record" "argocd" {
  zone      = "klimczak.xyz"
  subdomain = "argo"
  fieldtype = "A"
  ttl       = 3600
  target    = var.public_ip
}
```

- [ ] **Step 2: Format and validate**

Run: `terraform fmt ovh_domain.tf && terraform validate`
Expected: validate prints `Success! The configuration is valid.`

- [ ] **Step 3: Commit**

```bash
git add ovh_domain.tf
git commit -m "feat(argocd): add argo.klimczak.xyz DNS A-record"
```

---

### Task 5: Plan-level integration check

**Files:** none (verification only)

- [ ] **Step 1: Run a full plan to confirm the new resources wire together**

Run: `terraform plan`
Expected: plan succeeds with no errors. The diff shows planned creation of (at minimum):
`authentik_group.argocd_admins`, `authentik_provider_oauth2.argocd`,
`authentik_application.argocd`, `authentik_policy_binding.argocd_admins_required`,
`kubernetes_namespace.argocd`, `helm_release.argocd`, and `ovh_domain_zone_record.argocd`.
No unexpected destroys of existing resources.

> If the plan shows `+ create` for resources that already exist (e.g. other helm releases), that is the known kubeconfig-path issue noted in the repo's Terraform setup — confirm the kube config file referenced by `provider.tf` exists. It does not block the Argo CD resources.

- [ ] **Step 2: No commit (read-only step).**

---

### Task 6: Manual post-apply verification (run by the user)

**Files:** none

This task is the handoff checklist for after `terraform apply`. Not executed by the implementing agent.

- [ ] `kubectl -n argocd get pods` — all pods Ready.
- [ ] `https://argo.klimczak.xyz` serves a valid Let's Encrypt certificate.
- [ ] The login page shows only "Log in via Authentik" (no local username/password box).
- [ ] An `argocd-admins` member logs in and has admin rights.
- [ ] A non-member is denied (Authentik policy binding blocks the application).

---

## Self-Review

- **Spec coverage:** `argocd-oidc.tf` (Task 1) covers the Authentik group/provider/application/policy-binding; `values/argocd.yaml` (Task 2) covers OIDC config, RBAC, `admin.enabled: false`, ingress, insecure server; `argocd.tf` (Task 3) covers the Helm release + `set_sensitive` secret injection; `ovh_domain.tf` (Task 4) covers DNS. All spec sections mapped.
- **Placeholder scan:** No TBD/TODO/"handle appropriately" — every step has concrete content.
- **Consistency:** Application slug `argocd` (Task 1) matches the issuer `…/application/o/argocd/` (Task 2). The secret key `oidc.argocd.clientSecret` referenced in `values/argocd.yaml` (Task 2) matches the escaped `set_sensitive` key in `argocd.tf` (Task 3). Hostname `argo.klimczak.xyz` consistent across values, OIDC redirect URI, and DNS subdomain `argo`.
