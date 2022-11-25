output "endpoint" {
  value       = module.eks.cluster_endpoint
  description = "EKS cluster endpoint"
}

output "cluster_certificate_authority_data" {
  value       = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  description = "The base64 encoded certificate data required to communicate with your cluster"
}

output "token" {
  value       = data.aws_eks_cluster_auth.cluster.token
  description = "EKS cluster token"
}

output "oidc_provider_arn" {
  value       = module.eks.oidc_provider_arn
  description = "EKS OIDC provider ARN"
}

output "cluster_oidc_issuer_url" {
  value       = module.eks.cluster_oidc_issuer_url
  description = "EKS OIDC issues url"
}

output "worker_security_group_id" {
  value       = module.eks.worker_security_group_id
  description = "Kubernetes workers VPC Security group ID"
}

output "cluster_name" {
  value       = var.name
  description = "EKS Cluster name"
}
