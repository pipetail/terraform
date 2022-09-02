// https://github.com/aws-actions/configure-aws-credentials
resource "aws_iam_openid_connect_provider" "github" {
  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [
    data.tls_certificate.token.certificates[0].sha1_fingerprint
  ]

  url = "https://token.actions.githubusercontent.com"

  lifecycle {
    create_before_destroy = false
  }
}

data "tls_certificate" "token" {
  url = "https://token.actions.githubusercontent.com/.well-known/jwks"
}

resource "aws_iam_role" "github_actions" {
  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {

          StringLike = {                                                                // StringLike is important here for any wildcards on the line below
            "token.actions.githubusercontent.com:sub" = "repo:${var.repository_name}:*" // the last '*' allows ALL BRANCHES
          }
        }
      }
    ]
  })

  managed_policy_arns = var.managed_policy_arns
}
