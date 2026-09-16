resource "kubernetes_namespace" "metallb" {
  metadata {
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }

    name = "metallb"
  }
}

resource "helm_release" "metallb" {
  name       = "metallb"
  namespace  = "metallb"
  repository = "https://metallb.github.io/metallb"
  chart      = "metallb"
  version    = "0.15.2"
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
      addresses = ["192.168.1.30/32"]
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

resource "kubernetes_manifest" "metallb_samba_ip_pool" {
  depends_on = [helm_release.metallb]

  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "IPAddressPool"
    metadata = {
      name      = "samba-ip-pool"
      namespace = "metallb"
    }
    spec = {
      addresses  = ["192.168.1.32/32"]
      autoAssign = false
    }
  }
}

resource "kubernetes_manifest" "metallb_samba_l2_adv" {
  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "L2Advertisement"
    metadata = {
      name      = "samba-adv"
      namespace = "metallb"
    }
    spec = {
      ipAddressPools = ["samba-ip-pool"]
    }
  }
}
