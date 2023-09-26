output "certificate_arn" {
  value       = aws_acm_certificate_validation.main.certificate_arn
  description = "ACM certificate ARN"
}

output "virginia_certificate_arn" {
  value       = aws_acm_certificate.virginia.arn
  description = "ACM certificate ARN"
}
