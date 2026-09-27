output "cluster_name" {
  value       = module.eks.cluster_name
  description = "EKS cluster name, used by the e2e workflow to fetch a kubeconfig"
}
