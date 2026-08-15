# Root — manages only apex/shared DNS records.
# Each component is a standalone Terraform root in terraform/<component>/.
#
# Apply order on a fresh cluster:
#   1. terraform/vault/        — Vault, ESO, KMS unseal, k8s auth backend
#   2. terraform/auth/         — Authentik, all OIDC providers, writes secrets to Vault
#   3. terraform/infrastructure/ \
#      terraform/monitoring/    |  — independent, can run in parallel
#      terraform/services/      /
#
# For day-to-day changes apply only the relevant component directory.

resource "ovh_domain_name" "klimczak" {
  domain_name = "klimczak.xyz"
}

resource "ovh_domain_zone_record" "root" {
  zone      = "klimczak.xyz"
  subdomain = ""
  fieldtype = "A"
  ttl       = 3600
  target    = var.public_ip
}

resource "pihole_dns_record" "klimczak" {
  domain = "klimczak.xyz"
  ip     = "192.168.1.30"
}

# Netbird — DNS pre-created, not yet deployed.
resource "ovh_domain_zone_record" "netbird" {
  zone      = "klimczak.xyz"
  subdomain = "netbird"
  fieldtype = "A"
  ttl       = 3600
  target    = var.public_ip
}

resource "pihole_dns_record" "netbird" {
  domain = "netbird.klimczak.xyz"
  ip     = "192.168.1.30"
}
