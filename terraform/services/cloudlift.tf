# OVH zone records for cloudlift.run.
#
# cloudlift.pl was retired: its zone records, mailbox and TLS coverage were
# removed, and mail for that domain is no longer served here.

# homelab public IP (confirmed via cluster egress: 212.87.243.126)
variable "cloudlift_public_ip" {
  type    = string
  default = "212.87.243.126"
}

# ---------------------------------------------------------------------------
# cloudlift.run (mail moved here — customer address contact@cloudlift.run)
# Zone already exists on OVH (served by ns110/dns110.ovh.net, DNSSEC signed).
# OVH default records that conflict are removed manually via the go-ovh helper
# (/tmp/opencode/zoneops): default SPF "include:mx.ovh.com -all" and the
# mx1/2/3.mail.ovh.net MX set.
# ---------------------------------------------------------------------------

# mail.cloudlift.run -> public IP
resource "ovh_domain_zone_record" "cloudlift_run_mail" {
  zone      = "cloudlift.run"
  subdomain = "mail"
  fieldtype = "A"
  ttl       = 3600
  target    = var.cloudlift_public_ip
}

# MX: cloudlift.run -> mail.cloudlift.run
resource "ovh_domain_zone_record" "cloudlift_run_mx" {
  zone      = "cloudlift.run"
  subdomain = ""
  fieldtype = "MX"
  ttl       = 3600
  target    = "1 mail.cloudlift.run."
}

# SPF (apex TXT)
resource "ovh_domain_zone_record" "cloudlift_run_spf" {
  zone      = "cloudlift.run"
  subdomain = ""
  fieldtype = "TXT"
  ttl       = 3600
  target    = "v=spf1 mx include:mx.ovh.com a include:_spf.mlsend.com ~all"
}

# DMARC
resource "ovh_domain_zone_record" "cloudlift_run_dmarc" {
  zone      = "cloudlift.run"
  subdomain = "_dmarc"
  fieldtype = "TXT"
  ttl       = 3600
  target    = "v=DMARC1; p=quarantine; rua=mailto:admin@cloudlift.run; ruf=mailto:admin@cloudlift.run; fo=1"
}

# Apple auto-discovery helpers -> mail.cloudlift.run
resource "ovh_domain_zone_record" "cloudlift_run_autoconfig" {
  zone      = "cloudlift.run"
  subdomain = "autoconfig"
  fieldtype = "CNAME"
  ttl       = 3600
  target    = "mail.cloudlift.run."
}

resource "ovh_domain_zone_record" "cloudlift_run_autodiscover" {
  zone      = "cloudlift.run"
  subdomain = "autodiscover"
  fieldtype = "CNAME"
  ttl       = 3600
  target    = "mail.cloudlift.run."
}

# ---------------------------------------------------------------------------
# Service location records for mail clients.
#
# Clients discover settings three ways and each needs its own record set: the
# CNAMEs above cover Outlook's autodiscover URL and Thunderbird's autoconfig
# URL, while clients implementing RFC 6186 (and Outlook's SRV lookup) find the
# servers here instead.
#
# Only ports confirmed reachable from the internet are published: pointing a
# client at a port the router does not forward makes discovery fail where it
# would otherwise have fallen back to a working default. 993 and 465 are both
# confirmed — Outlook's connector reached them from outside.
# ---------------------------------------------------------------------------
locals {
  mail_srv_records = merge([
    for zone in ["cloudlift.run"] : {
      # priority weight port target
      "${zone}|imaps" = {
        zone      = zone
        subdomain = "_imaps._tcp"
        target    = "0 1 993 mail.${zone}."
      }
      "${zone}|submissions" = {
        zone      = zone
        subdomain = "_submissions._tcp"
        target    = "0 1 465 mail.${zone}."
      }
      "${zone}|autodiscover" = {
        zone      = zone
        subdomain = "_autodiscover._tcp"
        target    = "0 1 443 autodiscover.${zone}."
      }
    }
  ]...)
}

resource "ovh_domain_zone_record" "mail_srv" {
  for_each = local.mail_srv_records

  zone      = each.value.zone
  subdomain = each.value.subdomain
  fieldtype = "SRV"
  ttl       = 3600
  target    = each.value.target
}

# Submission over STARTTLS on 587. The listener exists and the LoadBalancer
# publishes it, but the router forward has not been confirmed, and a published
# SRV record would send RFC 6186 clients to it. Uncomment once 587/tcp reaches
# 192.168.1.31 from outside.
#
# resource "ovh_domain_zone_record" "mail_srv_submission" {
#   for_each = toset(["cloudlift.run"])
#
#   zone      = each.value
#   subdomain = "_submission._tcp"
#   fieldtype = "SRV"
#   ttl       = 3600
#   target    = "0 1 587 mail.${each.value}."
# }

# LAN DNS — Pi-hole overrides so home clients bypass the missing hairpin NAT.
# autoconfig/autodiscover (HTTPS) -> ingress controller; mail (IMAP/SMTP) -> mail LB.
resource "pihole_dns_record" "cloudlift_autoconfig" {
  domain = "autoconfig.cloudlift.run"
  ip     = "192.168.1.30"
}

resource "pihole_dns_record" "cloudlift_autodiscover" {
  domain = "autodiscover.cloudlift.run"
  ip     = "192.168.1.30"
}

resource "pihole_dns_record" "cloudlift_mail" {
  domain = "mail.cloudlift.run"
  ip     = "192.168.1.31"
}