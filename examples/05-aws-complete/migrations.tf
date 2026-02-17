# All state migrations go in this file. Using moved/import blocks instead of
# manual `terraform state mv` or `terraform import` commands keeps migrations
# versioned, reviewable, and safely applied across all environments.
#
# Applied moved blocks are no-ops and can stay here indefinitely as a history
# of refactors. Import blocks can be removed after they have been applied to
# all environments.

# --- moved: simple resource rename ---

moved {
  from = aws_alb.nginx
  to   = aws_alb.nginx_ingress
}

moved {
  from = aws_alb_target_group.nginx
  to   = aws_alb_target_group.nginx_ingress
}

# --- moved: module rename ---

moved {
  from = module.vpc_main
  to   = module.vpc
}

moved {
  from = module.sg_elasticache
  to   = module.sg_redis
}

# --- moved: extracting a resource into a module ---

moved {
  from = aws_cloudtrail.audit
  to   = module.cloudtrail.aws_cloudtrail.main
}

moved {
  from = aws_kms_key.encryption
  to   = aws_kms_key.main
}

# --- moved: for_each key rename ---

moved {
  from = aws_route53_record.dns["A"]
  to   = aws_route53_record.dns["a"]
}

# --- moved: count to for_each ---

moved {
  from = aws_elasticache_replication_group.cache[0]
  to   = aws_elasticache_replication_group.redis
}

# --- import: bring existing resources under Terraform management ---
# Remove import blocks after they have been applied to all environments.

# import {
#   to = aws_budgets_budget.cost
#   id = "overall-cost"
# }

# import {
#   to = aws_kms_key.main
#   id = "arn:aws:kms:eu-west-1:123456789012:key/12345678-1234-1234-1234-123456789012"
# }

# --- removed + import: resource type upgrade ---
# Use this pattern when upgrading resource types (e.g. kubernetes_namespace
# to kubernetes_namespace_v1). The removed block prevents Terraform from
# destroying the old resource, and the import block brings it under the new
# resource type.

# removed {
#   from = kubernetes_namespace.monitoring
#   lifecycle { destroy = false }
# }
#
# import {
#   to = kubernetes_namespace_v1.monitoring
#   id = "monitoring"
# }
