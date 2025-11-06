provider "pihole" {
  url      = "http://192.168.1.29:8081"
  password = var.pihole_password
}

resource "pihole_dns_record" "grafana" {
  domain = "grafana.klimczak.xyz"
  ip     = "192.168.1.29"
}

resource "pihole_dns_record" "budget-board" {
  domain = "budget.klimczak.xyz"
  ip     = "192.168.1.29"
}

resource "pihole_dns_record" "pass" {
  domain = "pass.klimczak.xyz"
  ip     = "192.168.1.29"
}

resource "pihole_dns_record" "vault" {
  domain = "vault.klimczak.xyz"
  ip     = "192.168.1.29"
}

resource "pihole_dns_record" "klimczak" {
  domain = "klimczak.xyz"
  ip     = "192.168.1.29"
}

