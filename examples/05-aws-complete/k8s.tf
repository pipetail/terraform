locals {
  ingress_ports = {
    https = 30443
  }
}

resource "helm_release" "traefik" {
  name = "traefik"

  namespace        = "traefik"
  create_namespace = true

  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = "41.0.2"

  wait   = true
  atomic = true

  values = [
    templatefile("${path.module}/helm-values/traefik.yaml.tftpl", {
      replica_count  = 3
      memory_request = "128Mi"
      memory_limit   = "128Mi"
      cpu_request    = "100m"
      https_nodeport = local.ingress_ports.https
      vpc_cidr       = module.vpc.vpc_cidr_block
    })
  ]
}
