resource "helm_release" "vikunja" {
  name       = "vikunja"
  namespace  = "vikunja"
  repository = "oci://ghcr.io/go-vikunja/helm-chart"
  chart      = "vikunja"
  create_namespace = true

  values = [
    file("values/vikunja.yaml")
  ]
}
