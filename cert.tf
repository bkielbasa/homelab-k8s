variable "internal_domains" {
  default = [
    "homepage.homelab",
    "vault.homelab",
    "freshrss.homelab"
  ]
}

resource "tls_private_key" "ca_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "ca_cert" {
  private_key_pem = tls_private_key.ca_key.private_key_pem

  subject {
    common_name  = "Homelab Internal CA"
    organization = "Homelab Internal CA"
  }

  validity_period_hours = 8760
  is_ca_certificate      = true

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
    "server_auth",
    "client_auth"
  ]
}

resource "tls_private_key" "internal_tls_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "internal_tls_req" {
  private_key_pem = tls_private_key.internal_tls_key.private_key_pem

  subject {
    common_name  = "books.homelab"
    organization = "Homelab Internal"
  }

  dns_names = var.internal_domains
}

resource "tls_locally_signed_cert" "internal_tls_cert" {
  cert_request_pem   = tls_cert_request.internal_tls_req.cert_request_pem
  ca_private_key_pem = tls_private_key.ca_key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca_cert.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth"
  ]
}

resource "kubernetes_secret" "internal_tls" {
  metadata {
    name      = "internal-tls"
    namespace = "internal"
  }

  data = {
    "tls.crt" = tls_locally_signed_cert.internal_tls_cert.cert_pem
    "tls.key" = tls_private_key.internal_tls_key.private_key_pem
  }

  type = "kubernetes.io/tls"
}

resource "kubernetes_secret" "freshrss_tls" {
  metadata {
    name      = "internal-tls"
    namespace = "freshrss"
  }

  data = {
    "tls.crt" = tls_locally_signed_cert.internal_tls_cert.cert_pem
    "tls.key" = tls_private_key.internal_tls_key.private_key_pem
  }

  type = "kubernetes.io/tls"

  depends_on = [helm_release.freshrss]
}

resource "kubernetes_secret" "homepage_tls" {
  metadata {
    name      = "internal-tls"
    namespace = "homepage"
  }

  data = {
    "tls.crt" = tls_locally_signed_cert.internal_tls_cert.cert_pem
    "tls.key" = tls_private_key.internal_tls_key.private_key_pem
  }

  type = "kubernetes.io/tls"
}

resource "kubernetes_secret" "wallabag_tls" {
  metadata {
    name      = "internal-tls"
    namespace = "wallabag"
  }

  data = {
    "tls.crt" = tls_locally_signed_cert.internal_tls_cert.cert_pem
    "tls.key" = tls_private_key.internal_tls_key.private_key_pem
  }

  type = "kubernetes.io/tls"
}

resource "kubernetes_secret" "vault_tls" {
  metadata {
    name      = "internal-tls"
    namespace = "vault"
  }

  data = {
    "tls.crt" = tls_locally_signed_cert.internal_tls_cert.cert_pem
    "tls.key" = tls_private_key.internal_tls_key.private_key_pem
  }

  type = "kubernetes.io/tls"

  depends_on = [helm_release.vault]
}
