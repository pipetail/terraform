// https://github.com/aws-actions/configure-aws-credentials
resource "aws_iam_openid_connect_provider" "github" {
  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = distinct(
    concat(
      [
        "6938fd4d98bab03faadb97b34396831e3780aea1",
        "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
      ],
      [for certificate in data.tls_certificate.token.certificates : certificate.sha1_fingerprint if certificate.is_ca]
    )
  )

  url = "https://token.actions.githubusercontent.com"

  lifecycle {
    create_before_destroy = false
  }
}

data "tls_certificate" "token" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
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
