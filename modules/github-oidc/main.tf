locals {
  // Defaults to the default branch only. Anything wider — PR runs, other
  // branches, environments — has to be named by the caller, so widening the
  // trust is a visible diff rather than a silent property of the module.
  allowed_subjects = coalesce(
    var.allowed_subjects,
    ["repo:${var.repository_name}:ref:refs/heads/master"],
  )
}

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
          // StringEquals, not StringLike: a pattern here is what lets any branch,
          // tag or PR of the repo mint credentials for this role. Subjects must be
          // enumerated exactly.
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = local.allowed_subjects
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  for_each = toset(var.managed_policy_arns)

  role       = aws_iam_role.github_actions.name
  policy_arn = each.value
}
