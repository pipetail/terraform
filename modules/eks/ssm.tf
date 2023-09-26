// this role is needed for access to bottlerocket instances via SSM
# resource "aws_iam_role_policy_attachment" "ssm" {
#   role       = module.eks.cluster_iam_role_name
#   policy_arn = data.aws_iam_policy.ssm.arn
# }
