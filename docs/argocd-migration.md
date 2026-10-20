# Moving services from Terraform helm_release to Argo CD

Status: **prepared, not yet applied.** Follow the runbook below in order —
step 2 is not optional (see the warning).

## What moved to Argo CD

| Service | Application | Chart (pinned) | Values |
|---|---|---|---|
| mariadb | `argocd-apps/mariadb.yaml` | bitnami/mariadb `26.2.0` | `values/mariadb.yaml` |
| valkey | `argocd-apps/valkey.yaml` | bitnami/valkey `5.0.1` | `values/valkey.yaml` |
| postgresql | `argocd-apps/postgresql.yaml` | local `helm/postgresql` | chart defaults |
| jellyfin | `argocd-apps/jellyfin.yaml` | jellyfin/jellyfin `3.2.0` | `values/jellyfin.yaml` |
| vaultwarden | `argocd-apps/vaultwarden.yaml` | vaultwarden `0.46.0` | `values/vaultwarden-values.yaml` |
| headlamp | `argocd-apps/headlamp.yaml` | headlamp `0.41.0` | `values/headlamp.yaml` |
| actualbudget | `argocd-apps/actualbudget.yaml` | actualbudget `1.9.4` | `values/actualbudget.yaml` + `values/actualbudget-image.yaml` |
| prometheus (grafana) | `argocd-apps/prometheus.yaml` | kube-prometheus-stack `70.4.1` | `values/prometheus.yaml` |
| loki | `argocd-apps/loki.yaml` | loki `7.1.0` | `values/loki.yaml` |
| alloy | `argocd-apps/alloy.yaml` | alloy `0.9.2` | `values/alloy.yaml` |
| tempo | `argocd-apps/tempo.yaml` | tempo `1.10.1` | `values/tempo.yaml` |

This is on top of the 6 apps that already ran under Argo CD (`darek`,
`ecommerce`, `freshrss`, `navidrome`, `smarthome-metrics`, `workspace`).

**Left in Terraform on purpose** (bootstrap/dependency-critical, or glue):
`vault`, `external-secrets`, `authentik`, `argocd`, `nginx-ingress`,
`metallb`, `linkerd-*`, `cert-manager-webhook-ovh` — plus, for every
migrated service, the namespace, DNS records, Authentik OIDC, and the new
Vault/ESO secret glue (`headlamp-vault.tf`, `actualbudget-vault.tf`,
`grafana-vault.tf`).

## How the Applications get applied

The new root app `homelab-apps` (created by
`terraform/infrastructure/argocd.tf`) tracks the `argocd-apps/` directory:
every Application file pushed to `master` is applied automatically, and
removing a file prunes that Application (its workloads are *not* deleted —
the child apps carry no `resources-finalizer`).

This replaces the manual `kubectl apply argocd-apps/` step.
(ApplicationSet was evaluated first, but its git *directory* generator only
produces path parameters from one static `spec.template` — it cannot drive
per-app chart sources. App-of-apps is the correct primitive here.)

## Runbook

### 1. Push to `master` first

Argo CD reads from GitHub, not your working copy:

```
git add -A && git commit -m "Move services to Argo CD" && git push
```

### 2. Drop the helm_releases from Terraform state — BEFORE applying

**Warning:** if you run `terraform apply` without this step, Terraform will
execute `helm uninstall` for each removed `helm_release`, deleting the
running workloads — including chart-managed PVCs (actualbudget, vaultwarden).
Run the helper script (idempotent, safe to re-run):

```
scripts/argocd-state-rm.sh
```

This only removes the resources from state; the releases keep running,
orphaned, until Argo adopts them minutes later.

### 3. Apply the roots (glue first, apps last)

```
terraform -chdir=terraform/services apply      # ESO glue for headlamp/actualbudget; releases untouched
terraform -chdir=terraform/monitoring apply    # grafana-env ESO glue; releases untouched
terraform -chdir=terraform/infrastructure apply # creates homelab-apps -> Argo adopts everything
```

Argo then reconciles within its 3-minute poll (or immediately via the
`argocd.argoproj.io/application-set-refresh`-style refresh / UI refresh):

```
kubectl get applications.argoproj.io -n argocd -w
```

### 4. Verify

```
kubectl get pods,ingress,certificate -n <svc>
curl -s -o /dev/null -w "%{http_code} %{ssl_verify_result}\n" https://<host>.klimczak.xyz/
```

Check Grafana login (OIDC) and the smarthome-metrics datasource, plus
headlamp/actualbudget SSO logins — those three changed secret plumbing
(`set_sensitive` → ExternalSecret).

## Adoption pre-check (already done)

For every app above, the chart was rendered exactly as Argo will render it
(release name = app name, pinned version, same values files) and diffed
against `helm get manifest`: **all 11 clean, zero resource-name mismatches.**
Known intended diffs only:

- `headlamp`: chart stops rendering `Secret/headlamp-k8s-oidc` (now
  `headlamp-oidc`, ESO-managed). The old Secret is untracked by Argo, so it
  lingers — delete it manually once the migration is healthy:
  `kubectl delete secret headlamp-k8s-oidc -n headlamp`
- `prometheus`: Grafana env switches from explicit env vars to
  `envFromSecrets` (same values, different wiring) — triggers one rollout.
  The app also needs `ServerSideApply=true` — kube-prometheus-stack's CRDs
  (`prometheuses.monitoring.coreos.com` etc.) are too large for Argo's
  client-side apply (256KiB `last-applied-configuration` annotation limit).

## After the migration

- **Helm leftovers:** each namespace still holds Argo-invisible
  `sh.helm.release.v1.*` Secrets from the Terraform era (harmless; they make
  `helm list` show ghosts). Optional cleanup: delete them per namespace.
- **Image bumps are now git-only:** with `selfHeal: true`, out-of-band
  `kubectl set image` / `helm upgrade` changes get reverted. The actualbudget
  bot keeps working — it commits `values/actualbudget-image.yaml`, and Argo
  now auto-deploys that push within ~3 minutes (previously it needed a
  Terraform apply).
- **New services** should follow the `add-cluster-service` skill: create the
  chart/values/OIDC/DNS/Vault glue as before, then add an
  `argocd-apps/<svc>.yaml` — no `helm_release` block.
