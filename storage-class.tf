<<<<<<< HEAD
# helm repo add csi-driver-nfs https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts
# helm repo update
# helm install csi-driver-nfs csi-driver-nfs/csi-driver-nfs \
#  --namespace kube-system \
#  --set kubeletDir=/var/lib/kubelet
resource "kubernetes_storage_class_v1" "qnap_nfs" {
  metadata {
    name = "qnap-nfs"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
=======
resource "kubernetes_storage_class_v1" "qnap_nfs" {
  metadata {
    name = "qnap-nfs"
>>>>>>> 2dfea70 (add qnap nfs storage class)
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
