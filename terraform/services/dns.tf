# DNS records for all services (both OVH public and Pi-hole LAN).
# The domain is klimczak.xyz; LAN IP is 192.168.1.30 (MetalLB LB).

# ---------------------------------------------------------------------------
# Jellyfin (subdomain: media)
# ---------------------------------------------------------------------------
resource "ovh_domain_zone_record" "jellyfin" {
  zone      = "klimczak.xyz"
  subdomain = "media"
  fieldtype = "A"
  ttl       = 3600
  target    = var.public_ip
}

resource "pihole_dns_record" "jellyfin" {
  domain = "media.klimczak.xyz"
  ip     = "192.168.1.30"
}

# ---------------------------------------------------------------------------
# ActualBudget (subdomain: budget)
# ---------------------------------------------------------------------------
resource "ovh_domain_zone_record" "actualbudget" {
  zone      = "klimczak.xyz"
  subdomain = "budget"
  fieldtype = "A"
  ttl       = 3600
  target    = var.public_ip
}

resource "pihole_dns_record" "budget-board" {
  domain = "budget.klimczak.xyz"
  ip     = "192.168.1.30"
}

# ---------------------------------------------------------------------------
# Vaultwarden (subdomain: pass)
# ---------------------------------------------------------------------------
resource "ovh_domain_zone_record" "vaultwarden" {
  zone      = "klimczak.xyz"
  subdomain = "pass"
  fieldtype = "A"
  ttl       = 3600
  target    = var.public_ip
}

resource "pihole_dns_record" "pass" {
  domain = "pass.klimczak.xyz"
  ip     = "192.168.1.30"
}

# ---------------------------------------------------------------------------
# Headlamp (subdomain: headlamp)
# ---------------------------------------------------------------------------
resource "ovh_domain_zone_record" "headlamp" {
  zone      = "klimczak.xyz"
  subdomain = "headlamp"
  fieldtype = "A"
  ttl       = 3600
  target    = var.public_ip
}

resource "pihole_dns_record" "headlamp" {
  domain = "headlamp.klimczak.xyz"
  ip     = "192.168.1.30"
}

# ---------------------------------------------------------------------------
# Darek (subdomain: darek)
# ---------------------------------------------------------------------------
resource "ovh_domain_zone_record" "darek" {
  zone      = "klimczak.xyz"
  subdomain = "darek"
  fieldtype = "A"
  ttl       = 3600
  target    = var.public_ip
}

resource "pihole_dns_record" "darek" {
  domain = "darek.klimczak.xyz"
  ip     = "192.168.1.30"
}

# ---------------------------------------------------------------------------
# FreshRSS (subdomain: rss)
# ---------------------------------------------------------------------------
resource "ovh_domain_zone_record" "freshrss" {
  zone      = "klimczak.xyz"
  subdomain = "rss"
  fieldtype = "A"
  ttl       = 3600
  target    = var.public_ip
}

resource "pihole_dns_record" "freshrss" {
  domain = "rss.klimczak.xyz"
  ip     = "192.168.1.30"
}

# ---------------------------------------------------------------------------
# Sentinel (subdomain: sentinel)
# ---------------------------------------------------------------------------
resource "ovh_domain_zone_record" "sentinel" {
  zone      = "klimczak.xyz"
  subdomain = "sentinel"
  fieldtype = "A"
  ttl       = 3600
  target    = var.public_ip
}

resource "pihole_dns_record" "sentinel" {
  domain = "sentinel.klimczak.xyz"
  ip     = "192.168.1.30"
}

# ---------------------------------------------------------------------------
# Navidrome (subdomain: audio)
# ---------------------------------------------------------------------------
resource "ovh_domain_zone_record" "navidrome" {
  zone      = "klimczak.xyz"
  subdomain = "audio"
  fieldtype = "A"
  ttl       = 3600
  target    = var.public_ip
}

resource "pihole_dns_record" "navidrome" {
  domain = "audio.klimczak.xyz"
  ip     = "192.168.1.30"
}
