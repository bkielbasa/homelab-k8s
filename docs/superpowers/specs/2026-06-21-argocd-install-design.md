# Argo CD install — design

**Date:** 2026-06-21
**Goal:** Deploy Argo CD to the homelab cluster at `argo.klimczak.xyz`, with SSO via
Authentik (direct OIDC, no Dex). Access gated to the `argocd-admins` Authentik group,
mapped to `role:admin`. The built-in local `admin` user is disabled — SSO is the only
way in. Follows the existing Grafana integration pattern.

## Scope

In scope: Authentik OIDC provider/application, Helm release, ingress + TLS, RBAC, DNS.

Out of scope (YAGNI): app-of-apps / bootstrap `Application`s, bundled Dex, HA topology,
notifications, ApplicationSet usage. Just a working SSO-gated Argo CD.

## Files

### 1. `argocd-oidc.tf` — Authentik side

Mirrors `grafana-oidc.tf` / `k8s-oidc.tf`. Reuses the shared data sources declared in
`vault-oidc.tf` (`default_authorization_flow`, `default_invalidation_flow`,
`authentik_certificate_key_pair.default`, `property_mapping_provider_scope.scopes`,
and the custom `property_mapping_provider_scope.groups`).

- `authentik_group "argocd_admins"` → name `argocd-admins`. Membership managed manually
  in the Authentik UI (same convention as `grafana-admins` / `vault-admins`).
- `authentik_provider_oauth2 "argocd"`:
  - `client_id = "argocd"`
  - shared authorization/invalidation flows + signing key
  - `property_mappings = concat(scopes.ids, [groups.id])` so the `groups` claim is emitted
  - `allowed_redirect_uris`:
    - `strict` → `https://argo.klimczak.xyz/auth/callback` (web UI)
    - `strict` → `http://localhost:8085/auth/callback` (argocd CLI SSO login)
- `authentik_application "argocd"`:
  - slug `argocd` (this drives the issuer URL `…/application/o/argocd/`)
  - `meta_launch_url = "https://argo.klimczak.xyz"`
  - `meta_icon` → Argo CD icon from the homarr-labs dashboard-icons CDN
- `authentik_policy_binding` binding `authentik_group.argocd_admins` to the application
  (`order = 0`). Gates login to that group, exactly like `kubernetes_admins_required` in
  `k8s-oidc.tf`.

### 2. `argocd.tf` — Helm release

Mirrors `monitoring.tf`'s `helm_release.prometheus`.

- `kubernetes_namespace "argocd"`.
- `helm_release "argocd"`:
  - `repository = "https://argoproj.github.io/argo-helm"`, `chart = "argo-cd"`,
    `version = "9.6.0"` (Argo CD v3.4.4 — current release as of writing).
  - `namespace` = the created namespace.
  - `values = [file("values/argocd.yaml")]`.
  - `set_sensitive` injects the OIDC client secret:
    - name: `configs.secret.extra.oidc\.argocd\.clientSecret`
      (dots inside the key are escaped so Helm treats `oidc.argocd.clientSecret` as a
      single key written into the `argocd-secret`).
    - value: `authentik_provider_oauth2.argocd.client_secret`.

### 3. `values/argocd.yaml`

- `global.domain: argo.klimczak.xyz`
- `configs.cm`:
  - `url: https://argo.klimczak.xyz`
  - `admin.enabled: false`  ← local admin disabled, SSO only
  - `oidc.config`:
    ```yaml
    name: Authentik
    issuer: https://authentik.klimczak.xyz/application/o/argocd/
    clientID: argocd
    clientSecret: $oidc.argocd.clientSecret
    requestedScopes: [openid, profile, email, groups]
    ```
- `configs.rbac`:
  - `policy.csv: "g, argocd-admins, role:admin"`
  - `policy.default: ''`  ← no access for anyone outside the group
  - `scopes: '[groups]'`
- `configs.params`:
  - `server.insecure: true`  ← nginx terminates TLS; argocd-server serves plain HTTP
- `server.ingress`:
  - `enabled: true`, `ingressClassName: nginx`, `hostname: argo.klimczak.xyz`
  - annotations: `cert-manager.io/cluster-issuer: letsencrypt-prod-dns`,
    `nginx.ingress.kubernetes.io/ssl-redirect: "true"`
  - `tls: true` (cert-manager issues the cert into the chart-managed TLS secret)

### 4. `ovh_domain.tf` — DNS

Add `ovh_domain_zone_record "argocd"`: zone `klimczak.xyz`, subdomain `argo`, type `A`,
ttl `3600`, target `var.public_ip`. Same shape as the existing records.

## Data flow

1. User visits `https://argo.klimczak.xyz` → nginx ingress → argocd-server (HTTP, insecure).
2. "Log in via Authentik" → OIDC dance against `authentik.klimczak.xyz`.
3. Authentik policy binding admits only `argocd-admins` members; token carries the
   `groups` claim.
4. Argo RBAC maps `argocd-admins` → `role:admin`; `policy.default: ''` denies everyone else.

## Verification (manual, after `terraform apply`)

- `kubectl -n argocd get pods` all Ready.
- `https://argo.klimczak.xyz` serves a valid Let's Encrypt cert and shows the Authentik
  login (no local admin login box).
- Logging in as an `argocd-admins` member lands with admin rights; a non-member is denied.
