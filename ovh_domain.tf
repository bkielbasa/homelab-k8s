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

resource "ovh_domain_zone_record" "vault" {
  zone      = "klimczak.xyz"
  subdomain = "vault"
  fieldtype = "A"
  ttl       = 3600
  target    = var.public_ip
}

resource "ovh_domain_zone_record" "darek" {
  zone      = "klimczak.xyz"
  subdomain = "darek"
  fieldtype = "A"
  ttl       = 3600
  target    = var.public_ip
}

resource "ovh_domain_zone_record" "authentik" {
  zone      = "klimczak.xyz"
  subdomain = "authentik"
  fieldtype = "A"
  ttl       = 3600
  target    = var.public_ip
}

resource "ovh_domain_zone_record" "headlamp" {
  zone      = "klimczak.xyz"
  subdomain = "headlamp"
  fieldtype = "A"
  ttl       = 3600
  target    = var.public_ip
}

resource "ovh_domain_zone_record" "jellyfin" {
  zone      = "klimczak.xyz"
  subdomain = "media"
  fieldtype = "A"
  ttl       = 3600
  target    = var.public_ip
}

resource "ovh_domain_zone_record" "netbird" {
  zone      = "klimczak.xyz"
  subdomain = "netbird"
  fieldtype = "A"
  ttl       = 3600
  target    = var.public_ip
}

resource "ovh_domain_zone_record" "sentinel" {
  zone      = "klimczak.xyz"
  subdomain = "sentinel"
  fieldtype = "A"
  ttl       = 3600
  target    = var.public_ip
}
