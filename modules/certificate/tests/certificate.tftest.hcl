mock_provider "aws" {
  override_during = plan

  mock_resource "aws_acm_certificate" {
    defaults = {
      arn                 = "arn:aws:acm:eu-central-1:123456789012:certificate/11111111-2222-3333-4444-555555555555"
      id                  = "arn:aws:acm:eu-central-1:123456789012:certificate/11111111-2222-3333-4444-555555555555"
      key_algorithm       = "RSA_2048"
      not_after           = ""
      not_before          = ""
      pending_renewal     = false
      region              = "eu-central-1"
      renewal_eligibility = "INELIGIBLE"
      renewal_summary     = []
      status              = "PENDING_VALIDATION"
      tags_all            = {}
      type                = "AMAZON_ISSUED"
      validation_emails   = []
      domain_validation_options = [
        {
          domain_name           = "example.com"
          resource_record_name  = "_a1.example.com."
          resource_record_type  = "CNAME"
          resource_record_value = "_b1.acm-validations.aws."
        },
        {
          domain_name           = "www.example.com"
          resource_record_name  = "_a2.www.example.com."
          resource_record_type  = "CNAME"
          resource_record_value = "_b2.acm-validations.aws."
        },
      ]
    }
  }
}

mock_provider "aws" {
  alias = "virginia"

  mock_resource "aws_acm_certificate" {
    defaults = {
      arn = "arn:aws:acm:us-east-1:123456789012:certificate/66666666-7777-8888-9999-000000000000"
    }
  }

  mock_resource "aws_acm_certificate_validation" {
    defaults = {
      region = "us-east-1"
    }
  }
}

variables {
  zone_id                   = "Z0123456789EXAMPLE"
  domain_name               = "example.com"
  subject_alternative_names = ["www.example.com"]
}

run "issues_matching_dns_validated_certificates_in_both_regions" {
  command = apply

  assert {
    condition     = aws_acm_certificate.main.validation_method == "DNS" && aws_acm_certificate.virginia.validation_method == "DNS"
    error_message = "Both certificates must use DNS validation."
  }

  assert {
    condition = alltrue([
      for c in [aws_acm_certificate.main, aws_acm_certificate.virginia] :
      c.domain_name == "example.com" && c.subject_alternative_names == toset(["www.example.com"])
    ])
    error_message = "Both certificates must cover the same domain name and SANs."
  }

  assert {
    condition     = startswith(output.virginia_certificate_arn, "arn:aws:acm:us-east-1:")
    error_message = "The virginia certificate must be created through the aws.virginia provider, since CloudFront only accepts certificates from us-east-1."
  }
}

run "creates_one_validation_record_per_domain" {
  command = apply

  assert {
    condition     = toset(keys(aws_route53_record.validation)) == toset(["example.com", "www.example.com"])
    error_message = "Each domain validation option must get its own Route53 record."
  }

  assert {
    condition = (
      aws_route53_record.validation["www.example.com"].name == "_a2.www.example.com." &&
      aws_route53_record.validation["www.example.com"].type == "CNAME" &&
      aws_route53_record.validation["www.example.com"].records == toset(["_b2.acm-validations.aws."])
    )
    error_message = "Validation records must carry the name, type and value ACM asked for."
  }

  assert {
    condition     = alltrue([for r in aws_route53_record.validation : r.zone_id == "Z0123456789EXAMPLE" && r.ttl == 60])
    error_message = "Validation records must go into the given zone with the default TTL."
  }
}

run "ttl_is_configurable" {
  command = apply

  variables {
    ttl = 300
  }

  assert {
    condition     = alltrue([for r in aws_route53_record.validation : r.ttl == 300])
    error_message = "The ttl variable must apply to every validation record."
  }
}

run "validates_the_regional_certificate_against_every_record" {
  command = apply

  assert {
    condition     = toset(aws_acm_certificate_validation.main.validation_record_fqdns) == toset([for r in aws_route53_record.validation : r.fqdn])
    error_message = "The validation resource must wait on every validation record."
  }

  assert {
    condition     = aws_acm_certificate_validation.main.certificate_arn == aws_acm_certificate.main.arn && output.certificate_arn == aws_acm_certificate.main.arn
    error_message = "The validation resource and the certificate_arn output must refer to the regional certificate."
  }
}

run "virginia_certificate_arn_waits_for_issuance" {
  command = apply

  assert {
    condition = (
      aws_acm_certificate_validation.virginia.certificate_arn == aws_acm_certificate.virginia.arn &&
      aws_acm_certificate_validation.virginia.region == "us-east-1"
    )
    error_message = "The us-east-1 certificate must have its own validation resource, created through the aws.virginia provider."
  }

  assert {
    condition     = toset(aws_acm_certificate_validation.virginia.validation_record_fqdns) == toset([for r in aws_route53_record.validation : r.fqdn])
    error_message = "The us-east-1 validation must wait on every validation record."
  }

  assert {
    condition     = output.virginia_certificate_arn == aws_acm_certificate_validation.virginia.certificate_arn
    error_message = "virginia_certificate_arn must come from the validation resource so consumers wait until the certificate is issued."
  }
}
