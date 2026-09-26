mock_provider "aws" {}
mock_provider "tls" {}

variables {
  repository_name = "example-org/example-repo"
}

run "trusts_only_the_master_branch_by_default" {
  command = apply

  assert {
    condition     = jsondecode(aws_iam_role.github_actions.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] == ["repo:example-org/example-repo:ref:refs/heads/master"]
    error_message = "Without allowed_subjects the role must trust only the master branch of the repository."
  }

  assert {
    condition     = keys(jsondecode(aws_iam_role.github_actions.assume_role_policy).Statement[0].Condition) == ["StringEquals"]
    error_message = "The trust policy must match subjects with StringEquals only. StringLike lets any branch, tag or PR assume the role."
  }

  assert {
    condition     = jsondecode(aws_iam_role.github_actions.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:aud"] == "sts.amazonaws.com"
    error_message = "The trust policy must require the sts.amazonaws.com audience."
  }
}

run "allowed_subjects_replace_the_default" {
  command = apply

  variables {
    allowed_subjects = [
      "repo:example-org/example-repo:pull_request",
      "repo:example-org/example-repo:environment:prod",
    ]
  }

  assert {
    condition = jsondecode(aws_iam_role.github_actions.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] == [
      "repo:example-org/example-repo:pull_request",
      "repo:example-org/example-repo:environment:prod",
    ]
    error_message = "allowed_subjects must replace the master-branch default exactly, not extend it."
  }
}

run "attaches_each_managed_policy" {
  command = apply

  variables {
    managed_policy_arns = [
      "arn:aws:iam::aws:policy/ReadOnlyAccess",
      "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess",
    ]
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.github_actions) == 2
    error_message = "Each managed policy ARN must get its own attachment."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.github_actions["arn:aws:iam::aws:policy/ReadOnlyAccess"].role == var.role_name
    error_message = "Policy attachments must target the created role."
  }
}

run "keeps_the_pinned_github_thumbprints" {
  command = apply

  assert {
    condition = alltrue([
      contains(aws_iam_openid_connect_provider.github.thumbprint_list, "6938fd4d98bab03faadb97b34396831e3780aea1"),
      contains(aws_iam_openid_connect_provider.github.thumbprint_list, "1c58a3a8518e8759bf075b76b750d4f2df264fcd"),
    ])
    error_message = "The two GitHub OIDC thumbprints must stay pinned even when the live certificate chain returns nothing."
  }
}
