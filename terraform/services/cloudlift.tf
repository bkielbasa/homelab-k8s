# OVH zone records for cloudlift.pl (migrated from Cloudflare).
#
# Prerequisite (done once in the OVH dashboard / API):
#   1. Activate the cloudlift.pl zone in the OVH account (POST /domain/cloudlift.pl/activateZone).
#   2. At the registrar, point cloudlift.pl NS to the OVH nameservers that serve
#      klimczak.xyz (ns19.ovh.net + dns19.ovh.net) and wait for propagation.
#
# Only the mail-critical records are created here. Records that were served by
# Cloudflare's proxy (apex A, www, grafana, ...) need a human decision about the
# real origin IP — they are listed as comments further down.

# homelab public IP (confirmed via cluster egress: 212.87.243.126)
variable "cloudlift_public_ip" {
  type    = string
  default = "212.87.243.126"
}

# mail.cloudlift.pl -> public IP (used by IMAPS 993 / SMTPS 465 / HTTPS)
resource "ovh_domain_zone_record" "cloudlift_mail" {
  zone      = "cloudlift.pl"
  subdomain = "mail"
  fieldtype = "A"
  ttl       = 3600
  target    = var.cloudlift_public_ip
}

# MX: cloudlift.pl -> mail.cloudlift.pl
resource "ovh_domain_zone_record" "cloudlift_mx" {
  zone      = "cloudlift.pl"
  subdomain = ""
  fieldtype = "MX"
  ttl       = 3600
  target    = "1 mail.cloudlift.pl."
}

# SPF (apex TXT)
resource "ovh_domain_zone_record" "cloudlift_spf" {
  zone      = "cloudlift.pl"
  subdomain = ""
  fieldtype = "TXT"
  ttl       = 3600
  target    = "v=spf1 mx include:mx.ovh.com a include:_spf.mlsend.com ~all"
}

# DMARC
resource "ovh_domain_zone_record" "cloudlift_dmarc" {
  zone      = "cloudlift.pl"
  subdomain = "_dmarc"
  fieldtype = "TXT"
  ttl       = 3600
  target    = "v=DMARC1; p=quarantine; rua=mailto:admin@cloudlift.pl; ruf=mailto:admin@cloudlift.pl; fo=1"
}

# Apple auto-discovery helpers -> mail.cloudlift.pl
resource "ovh_domain_zone_record" "cloudlift_autoconfig" {
  zone      = "cloudlift.pl"
  subdomain = "autoconfig"
  fieldtype = "CNAME"
  ttl       = 3600
  target    = "mail.cloudlift.pl."
}

resource "ovh_domain_zone_record" "cloudlift_autodiscover" {
  zone      = "cloudlift.pl"
  subdomain = "autodiscover"
  fieldtype = "CNAME"
  ttl       = 3600
  target    = "mail.cloudlift.pl."
}

# Records that lived behind the Cloudflare proxy and NEED A DECISION before apply
# (currently commented out so apply stays safe):
#
# resource "ovh_domain_zone_record" "cloudlift_apex" {
#   zone      = "cloudlift.pl"
#   subdomain = ""
#   fieldtype = "A"
#   ttl       = 3600
#   target    = var.cloudlift_public_ip   # confirm apex actually serves from the homelab
# }
#
# resource "ovh_domain_zone_record" "cloudlift_www" {
#   zone      = "cloudlift.pl"
#   subdomain = "www"
#   fieldtype = "CNAME"
#   ttl       = 3600
#   target    = "cloudlift.pl."
# }
#
# grafana.cloudlift.pl was 130.61.226.152 (OCI) — decide whether it moves to OVH too.

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
# servers here instead. Both mail zones are served by the same host, so they
# get the same records.
#
# Only ports confirmed reachable from the internet are published: pointing a
# client at a port the router does not forward makes discovery fail where it
# would otherwise have fallen back to a working default. 993 and 465 are both
# confirmed — Outlook's connector reached them from outside.
# ---------------------------------------------------------------------------
locals {
  mail_srv_records = merge([
    for zone in ["cloudlift.run", "cloudlift.pl"] : {
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
#   for_each = toset(["cloudlift.run", "cloudlift.pl"])
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