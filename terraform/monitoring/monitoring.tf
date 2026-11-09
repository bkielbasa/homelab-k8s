# Grafana's OIDC client secret and the smarthome-metrics DB password are
# synced from Vault into the grafana-env Secret by ExternalSecret — see
# grafana-vault.tf. The workloads (prometheus/loki/alloy/tempo) are managed
# by Argo CD — see argocd-apps/*.yaml. This root keeps the DNS records and
# the linkerd-proxy ServiceMonitor.

resource "ovh_domain_zone_record" "grafana" {
  zone      = "klimczak.xyz"
  subdomain = "grafana"
  fieldtype = "A"
  ttl       = 3600
  target    = var.public_ip
}

resource "pihole_dns_record" "grafana" {
  domain = "grafana.klimczak.xyz"
  ip     = "192.168.1.30"
}

# Linkerd monitoring removed: control plane is currently broken on NixOS
# nodes (missing ip_tables kernel module), so these targets never become
# healthy. Re-add once linkerd is fixed or replaced.
