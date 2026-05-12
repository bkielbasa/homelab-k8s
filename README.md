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

| URL | Service |
|---|---|
| `klimczak.xyz` | Nextcloud |
| `media.klimczak.xyz` | Jellyfin |
| `audio.klimczak.xyz` | Audiobookshelf |
| `budget.klimczak.xyz` | Actual Budget |
| `rss.klimczak.xyz` | FreshRSS |
| `pass.klimczak.xyz` | Vaultwarden |
| `vault.klimczak.xyz` | Vault |
| `authentik.klimczak.xyz` | Authentik |
| `grafana.klimczak.xyz` | Grafana / Prometheus / Loki / Tempo / Alloy |
| `headlamp.klimczak.xyz` | Headlamp (k8s UI) |
| `darek.klimczak.xyz` | Darek (custom app) |

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

## Gotchas

1. **Default kubectl context is the work cluster.** Set `KUBECONFIG=~/.kube/malinka-oidc` (or `~/.kube/malinka`) before running cluster commands — running them against the default `prod` context will hit the wrong cluster.
2. **Authentik users must have an email.** Any user that authenticates into Grafana, Nextcloud, or Vault via OIDC needs the email field populated; otherwise Grafana falls back to a non-existent `/emails` endpoint and login fails.
3. **Router port-forward must target `192.168.1.30`** (nginx-ingress), not `192.168.1.29` (pi-hole). If it hits pi-hole, external clients get pi-hole's self-signed cert.
4. **`pihole.tf` is the source of truth for LAN DNS overrides.** Adding a new service requires both an OVH `A` record (in `ovh_domain.tf`) and a pi-hole record (in `pihole.tf`) — otherwise LAN clients resolve to the public IP and hairpin-NAT through the router.
5. **`values/actualbudget-image.yaml`** is the only file the version-bump bot is allowed to touch. The rest of actualbudget's config lives in `values/actualbudget.yaml` so a bot bump can't strip ingress config.
