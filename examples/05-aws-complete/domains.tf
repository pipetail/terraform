data "aws_route53_zone" "primary" {
  name = var.dns_zone_suffix
}

resource "aws_route53_record" "api" {
  # checkov:skip=CKV2_AWS_23:ALB is attached
  for_each = toset(["A", "AAAA"])

  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "api.${var.dns_zone_suffix}"
  type    = each.value

  alias {
    name                   = aws_alb.nginx_ingress.dns_name
    zone_id                = aws_alb.nginx_ingress.zone_id
    evaluate_target_health = false
  }
}
