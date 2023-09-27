locals {
  nginx_ingress_ports = {
    http  = 30080
    https = 30443
  }
}

resource "helm_release" "nginx_ingress" {
  name = "nginx-ingress"

  namespace        = "nginx-ingress"
  create_namespace = true

  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.6.1"

  wait   = true
  atomic = true

  values = [
    templatefile("${path.module}/helm-values/nginx-ingress.yaml", {
      replica_count  = 3
      memory_request = "128Mi"
      memory_limit   = "128Mi"
      cpu_request    = "100m"
      http_nodeport  = local.nginx_ingress_ports.http
      https_nodeport = local.nginx_ingress_ports.https
    })
  ]
}
