resource "helm_release" "audiobookshelf" {
  name             = "audiobookshelf"
  namespace        = "audiobookshelf"
  chart            = "./helm/audiobookshelf"
  create_namespace = true

  values = [
    file("values/audiobookshelf.yaml")
  ]
}
