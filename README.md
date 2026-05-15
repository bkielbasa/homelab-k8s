# homelab-k8s

Terraform-managed Kubernetes homelab. Everything that can be codified is codified — apps, ingresses, DNS records (pi-hole and OVH), SSO providers, and secrets.

## Stack

- **Cluster:** single-machine Kubernetes (node: `laptop`)
- **Ingress:** nginx-ingress at `192.168.1.30` (MetalLB-allocated)
- **DNS:** pi-hole at `192.168.1.29` for LAN, OVH for the public `klimczak.xyz` zone
- **Storage:** QNAP NFS at `192.168.1.148` (default StorageClass `qnap-nfs` via `csi-driver-nfs`; a few static PVs)
- **TLS:** cert-manager + Let's Encrypt, DNS-01 via OVH (port 80 is not forwarded)
- **SSO:** Authentik — every OIDC app points at `authentik.klimczak.xyz`
- **Secrets:** Vault at `vault.klimczak.xyz`, surfaced into k8s via External Secrets
- **State:** Terraform state in S3 (see `env.example`)

## Services

**User-facing apps**

- Nextcloud — `klimczak.xyz`
- Jellyfin — `media.klimczak.xyz`
- Actual Budget — `budget.klimczak.xyz`
- FreshRSS — `rss.klimczak.xyz`
- Vaultwarden — `pass.klimczak.xyz`
- Vault — `vault.klimczak.xyz`
- Authentik (SSO) — `authentik.klimczak.xyz`
- Grafana (with Prometheus, Loki, Tempo, Alloy) — `grafana.klimczak.xyz`
- Headlamp (Kubernetes UI) — `headlamp.klimczak.xyz`
- Darek (custom app) — `darek.klimczak.xyz`
- NetBird (VPN) — `netbird.klimczak.xyz`

**Infrastructure**

- nginx-ingress
- cert-manager + cert-manager-webhook-ovh (DNS-01 via OVH)
- MetalLB
- Linkerd (service mesh)
- External Secrets (Vault → k8s)
- csi-driver-nfs (default StorageClass `qnap-nfs`)
- PostgreSQL, MariaDB, Valkey
- Kubernetes API OIDC (via Authentik)
- pi-hole local DNS records (managed in `pihole.tf`)
- OVH `klimczak.xyz` DNS zone records (managed in `ovh_domain.tf`)
- NetBird routing peer (DaemonSet on `laptop`, advertises `192.168.1.0/24`)

## Operating

**Prerequisites**

- Two kubeconfigs:
  - `~/.kube/malinka` — terraform provider config (referenced in `provider.tf`)
  - `~/.kube/malinka-oidc` — daily `kubectl` work, context `oidc@malinka`
- AWS creds for the S3 state backend (see `env.example`)
- `VAULT_TOKEN` set for terraform to read secrets from Vault
- OVH API credentials (`ovh_app_key`, `ovh_app_secret`, `ovh_consumer_key`) — in `terraform.tfvars` or env

**Manual prerequisites (not Terraform-managed)**

- PostgreSQL `netbird` database — created once via `./psql_create_db.sh netbird`. The generated DSN goes into Vault at `secret/netbird/datastore.postgresDSN`. The role's password must be URL-safe (hex chars only); the default script output contains `/` so re-roll with `openssl rand -hex 24` if needed.
- Authentik service-account `netbird-idp` needs the built-in **`authentik Read-only`** role assigned via the UI (Directory → Users → netbird-idp → Roles tab). Plus membership in **`authentik Admins`** is set via Terraform — the role-only path didn't grant enough API permission scope.
- NetBird routing-peer setup key is generated once in the NetBird dashboard and stored in Vault at `secret/netbird/router.setup_key`.
- NetBird dashboard configuration (in the NetBird UI): one `Network Route` for `192.168.1.0/24` against the `homelab-router` peer, plus a `Nameserver Group` pushing `192.168.1.29` (pi-hole) for the `klimczak.xyz` match domain.

**Day-to-day**

```sh
terraform plan
terraform apply
```

For a single resource, target it: `terraform apply -target=helm_release.<name>`.

For ad-hoc `kubectl`:

```sh
export KUBECONFIG=~/.kube/malinka-oidc
kubectl get pods -A
```
