resource "kubernetes_storage_class_v1" "qnap_nfs" {
  metadata {
    name = "qnap-nfs"
  }

  storage_provisioner    = "nfs.csi.k8s.io"
  reclaim_policy        = "Retain"
  volume_binding_mode   = "Immediate"
  allow_volume_expansion = true

  parameters = {
    server = "192.168.1.148"
    share  = "/k8s"
  }

  mount_options = [
    "nfsvers=4.1",
    "hard",
    "timeo=600",
    "retrans=2",
    "noresvport"
  ]
}
