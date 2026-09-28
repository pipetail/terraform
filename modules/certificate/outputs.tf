output "certificate_arn" {
  value       = aws_acm_certificate_validation.main.certificate_arn
  description = "ACM certificate ARN"
}

output "virginia_certificate_arn" {
  value       = aws_acm_certificate_validation.virginia.certificate_arn
  description = "ARN of the us-east-1 copy of the ACM certificate, for CloudFront"
}
