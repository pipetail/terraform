# // roles and identity providers for GitHub Actions
# module "github_oidc" {
#   source = "../../modules/github-oidc"

#   # you can easily do `repository_name = "pipetail/terraform-*"` to match all repos that start with `terraform-` prefix
#   repository_name = "pipetail/terraform"

#   # you can use Managed Policy Arns to attach to the created role
#   managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"]
# }

// roles and identity providers for GitHub Actions
module "github_oidc_custom_policy" {
  source = "../../modules/github-oidc"

  repository_name = "pipetail/terraform"

  # we don't use managed_policy_arns here to specify a custom policy
}

resource "aws_iam_role_policy" "github_actions_push_to_ecr" {
  name   = "github-actions-push-to-ecr"
  role   = module.github_oidc_custom_policy.role_name
  policy = data.aws_iam_policy_document.ecr_push_only.json
}

data "aws_iam_policy_document" "ecr_push_only" {

  statement {

    actions = [
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]

    resources = [
      aws_ecr_repository.test.arn
    ]
  }
}

resource "aws_ecr_repository" "test" {
  #checkov:skip=CKV_AWS_136: Not using KMS encryption here for simplicity
  name = "test"

  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}
