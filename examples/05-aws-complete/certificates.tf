module "certificate" {
  source = "../../modules/certificate"

  providers = {
    aws          = aws
    aws.virginia = aws.virginia
  }

  zone_id     = data.aws_route53_zone.primary.id
  domain_name = "*.${data.aws_route53_zone.primary.name}"

  subject_alternative_names = [
    data.aws_route53_zone.primary.name
  ]
}
