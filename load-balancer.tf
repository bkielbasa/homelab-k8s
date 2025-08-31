resource "helm_release" "metallb" {
  name       = "metallb"
  namespace  = "metallb"
  repository = "https://metallb.github.io/metallb"
  chart      = "metallb"
  version    = "0.15.2"
}

resource "kubernetes_namespace" "metallb" {
  metadata {
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit" = "privileged"
      "pod-security.kubernetes.io/warn" = "privileged"
    }

    name = "metallb"
  }
}

resource "kubernetes_manifest" "metallb_ip_pool" {
  depends_on = [helm_release.metallb]

  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "IPAddressPool"
    metadata = {
      name      = "nginx-ip-pool"
      namespace = "metallb"
    }
    spec = {
      addresses = ["192.168.1.29/32"]
    }
  }
}

resource "kubernetes_manifest" "metallb_l2_adv" {
  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "L2Advertisement"
    metadata = {
      name      = "nginx-adv"
      namespace = "metallb"
    }
    spec = {
      ipAddressPools = ["nginx-ip-pool"]
    }
  }
}
