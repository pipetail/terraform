mock_provider "aws" {}

variables {
  external_id           = "example-external-id-0123456789"
  portal_aws_account_id = "123456789012"
}

run "trust_policy_requires_the_external_id" {
  command = apply

  assert {
    condition     = length(jsondecode(aws_iam_role.pipetail_cloud.assume_role_policy).Statement) == 1
    error_message = "The trust policy must hold exactly one statement, so no second statement can grant assume without the external ID."
  }

  assert {
    condition     = jsondecode(aws_iam_role.pipetail_cloud.assume_role_policy).Statement[0].Principal.AWS == "arn:aws:iam::123456789012:root"
    error_message = "Only the portal account may be trusted."
  }

  assert {
    condition     = jsondecode(aws_iam_role.pipetail_cloud.assume_role_policy).Statement[0].Action == "sts:AssumeRole"
    error_message = "The trust policy must grant sts:AssumeRole only."
  }

  assert {
    condition     = jsondecode(aws_iam_role.pipetail_cloud.assume_role_policy).Statement[0].Condition.StringEquals["sts:ExternalId"] == "example-external-id-0123456789"
    error_message = "The trust policy must require the external ID with StringEquals."
  }
}

run "scan_policy_grants_only_read_actions" {
  command = apply

  assert {
    condition     = alltrue([for s in jsondecode(aws_iam_role_policy.scan_read.policy).Statement : s.Effect == "Allow"])
    error_message = "The scan policy must contain only Allow statements."
  }

  assert {
    condition = alltrue(flatten([
      for s in jsondecode(aws_iam_role_policy.scan_read.policy).Statement : [
        for a in flatten([s.Action]) : !strcontains(a, "*")
      ]
    ]))
    error_message = "The scan policy must name each action; a wildcard can grant write actions."
  }

  assert {
    condition = alltrue(flatten([
      for s in jsondecode(aws_iam_role_policy.scan_read.policy).Statement : [
        for a in flatten([s.Action]) : !can(regex("^(Put|Create|Delete|Update|Attach|Detach|Modify|Set|Tag|Untag)", split(":", a)[1]))
      ]
    ]))
    error_message = "The scan policy must not grant any Put, Create, Delete, Update, Attach, Detach, Modify, Set, Tag or Untag action."
  }

  assert {
    condition = alltrue(flatten([
      for s in jsondecode(aws_iam_role_policy.scan_read.policy).Statement : [
        for a in flatten([s.Action]) : can(regex("^(Describe|Get|List|Lookup|View|GenerateCredentialReport$)", split(":", a)[1])) || a == "apigateway:GET"
      ]
    ]))
    error_message = "Every scan action must be a Describe, Get, List, Lookup or View call (plus iam:GenerateCredentialReport and the path-scoped apigateway:GET)."
  }

  assert {
    condition = length([
      for s in jsondecode(aws_iam_role_policy.scan_read.policy).Statement : s
      if contains(flatten([s.Action]), "apigateway:GET")
    ]) == 1
    error_message = "apigateway:GET must be granted in exactly one statement."
  }

  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_role_policy.scan_read.policy).Statement :
      flatten([s.Action]) == ["apigateway:GET"] && sort(flatten([s.Resource])) == sort(["arn:aws:apigateway:*::/restapis", "arn:aws:apigateway:*::/restapis/*/stages"])
      if anytrue([for a in flatten([s.Action]) : startswith(a, "apigateway:")])
    ])
    error_message = "API Gateway reads must be limited to the REST API list and its stages; any wider path can return API key values."
  }

  assert {
    condition     = aws_iam_role_policy.scan_read.role == aws_iam_role.pipetail_cloud.id
    error_message = "The scan policy must be attached to the created role."
  }
}

run "scan_read_lists_amis_and_billed_cost" {
  command = apply

  assert {
    condition = length(setsubtract(
      ["ce:GetCostAndUsage", "ec2:DescribeImages", "ec2:DescribeLaunchTemplateVersions"],
      flatten([
        for s in jsondecode(aws_iam_role_policy.scan_read.policy).Statement : flatten([s.Action])
        if s.Sid == "PipetailScanRead" && s.Resource == "*"
      ])
    )) == 0
    error_message = "PipetailScanRead must grant ce:GetCostAndUsage, ec2:DescribeImages and ec2:DescribeLaunchTemplateVersions; the portal checks its advertised actions against that statement only."
  }
}

run "exposes_the_role_name" {
  command = apply

  variables {
    role_name = "example-scan-role"
  }

  assert {
    condition     = output.role_name == "example-scan-role"
    error_message = "role_name must create the role under that name."
  }

  assert {
    condition     = output.role_arn == aws_iam_role.pipetail_cloud.arn
    error_message = "role_arn must expose the created role's ARN."
  }
}

run "rejects_an_empty_external_id" {
  command = plan

  variables {
    external_id = ""
  }

  expect_failures = [var.external_id]
}

run "rejects_a_malformed_portal_account_id" {
  command = plan

  variables {
    portal_aws_account_id = "12345"
  }

  expect_failures = [var.portal_aws_account_id]
}
