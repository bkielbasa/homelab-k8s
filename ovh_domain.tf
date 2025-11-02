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
