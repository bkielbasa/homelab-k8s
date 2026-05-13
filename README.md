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
- Audiobookshelf — `audio.klimczak.xyz`
- Actual Budget — `budget.klimczak.xyz`
- FreshRSS — `rss.klimczak.xyz`
- Vaultwarden — `pass.klimczak.xyz`
- Vault — `vault.klimczak.xyz`
- Authentik (SSO) — `authentik.klimczak.xyz`
- Grafana (with Prometheus, Loki, Tempo, Alloy) — `grafana.klimczak.xyz`
- Headlamp (Kubernetes UI) — `headlamp.klimczak.xyz`
- Darek (custom app) — `darek.klimczak.xyz`

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

## Operating

**Prerequisites**

- Two kubeconfigs:
  - `~/.kube/malinka` — terraform provider config (referenced in `provider.tf`)
  - `~/.kube/malinka-oidc` — daily `kubectl` work, context `oidc@malinka`
- AWS creds for the S3 state backend (see `env.example`)
- `VAULT_TOKEN` set for terraform to read secrets from Vault
- OVH API credentials (`ovh_app_key`, `ovh_app_secret`, `ovh_consumer_key`) — in `terraform.tfvars` or env

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
