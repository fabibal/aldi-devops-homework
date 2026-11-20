resource "kubernetes_namespace" "homework" {
  metadata {
    name = var.namespace # was: "production"
  }
}

resource "helm_release" "homework" {
  name      = "myapp"                  # was: "homework"
  chart     = "${path.module}/../helm" # was: "../helm/homework"
  namespace = kubernetes_namespace.homework.metadata[0].name

  set {
    name  = "image.tag"
    value = var.image_tag # was: (empty)
  }

  set {
    name  = "environment"
    value = var.environment # was: prod
  }
}
