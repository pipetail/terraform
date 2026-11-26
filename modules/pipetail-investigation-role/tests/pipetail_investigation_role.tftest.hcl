mock_provider "aws" {}

run "trust_policy_allows_one_role_with_the_session_name" {
  command = apply

  variables {
    principal_arn = "arn:aws:iam::123456789012:role/example-agent"
  }

  assert {
    condition     = length(jsondecode(aws_iam_role.investigation.assume_role_policy).Statement) == 1
    error_message = "The trust policy must hold exactly one statement, so no second statement can grant assume without the session name."
  }

  assert {
    condition     = jsondecode(aws_iam_role.investigation.assume_role_policy).Statement[0].Effect == "Allow"
    error_message = "The trust statement must be an Allow."
  }

  assert {
    condition     = jsondecode(aws_iam_role.investigation.assume_role_policy).Statement[0].Principal.AWS == "arn:aws:iam::123456789012:role/example-agent"
    error_message = "Only principal_arn may be trusted."
  }

  assert {
    condition     = jsondecode(aws_iam_role.investigation.assume_role_policy).Statement[0].Action == "sts:AssumeRole"
    error_message = "The trust policy must grant sts:AssumeRole only."
  }

  assert {
    condition     = jsondecode(aws_iam_role.investigation.assume_role_policy).Statement[0].Condition.StringEquals["sts:RoleSessionName"] == "gate-host-agent"
    error_message = "The trust policy must require the session name gate-host-agent with StringEquals."
  }

  assert {
    condition     = aws_iam_role.investigation.max_session_duration == 3600
    error_message = "The role session must last at most one hour."
  }
}

run "defaults_to_the_gate_host_agent_role" {
  command = plan

  assert {
    condition     = jsondecode(aws_iam_role.investigation.assume_role_policy).Statement[0].Principal.AWS == "arn:aws:iam::680177765279:role/gate-host-agent"
    error_message = "The default principal must be the gate host agent role."
  }

  assert {
    condition     = aws_iam_role.investigation.name == "pipetailInvestigation"
    error_message = "The default role name must be pipetailInvestigation."
  }
}

run "attaches_read_only_access" {
  command = apply

  assert {
    condition     = aws_iam_role_policy_attachment.read_only.policy_arn == "arn:aws:iam::aws:policy/ReadOnlyAccess"
    error_message = "The role must have the AWS managed ReadOnlyAccess policy attached."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.read_only.role == aws_iam_role.investigation.name
    error_message = "ReadOnlyAccess must be attached to the created role."
  }

  assert {
    condition     = aws_iam_role_policy.deny_data_reads.role == aws_iam_role.investigation.id
    error_message = "The Deny policy must be attached to the created role."
  }
}

run "deny_policy_denies_every_data_read" {
  command = apply

  assert {
    condition     = alltrue([for s in jsondecode(aws_iam_role_policy.deny_data_reads.policy).Statement : s.Effect == "Deny"])
    error_message = "The inline policy must contain only Deny statements; ReadOnlyAccess is the only Allow."
  }

  assert {
    condition = length(setsubtract(
      [
        "amplify:GetBackendEnvironment",
        "amplify:GetBranch",
        "appconfig:GetConfiguration",
        "appconfig:GetHostedConfigurationVersion",
        "appconfig:GetLatestConfiguration",
        "athena:GetQueryResults",
        "athena:GetQueryResultsStream",
        "bedrock-agentcore:GetEvent",
        "bedrock-agentcore:GetMemoryRecord",
        "bedrock-agentcore:ListEvents",
        "bedrock-agentcore:ListMemoryRecords",
        "bedrock-agentcore:RetrieveMemoryRecords",
        "bedrock:AgenticRetrieveStream",
        "bedrock:GetDocumentContent",
        "bedrock:Retrieve",
        "cassandra:Select",
        "codebuild:BatchGetProjects",
        "codecommit:GetBlob",
        "codecommit:GetFile",
        "codecommit:GetFolder",
        "codecommit:GitPull",
        "cognito-idp:AdminGetDevice",
        "cognito-idp:AdminGetUser",
        "cognito-idp:AdminListDevices",
        "cognito-idp:AdminListUserAuthEvents",
        "cognito-idp:ListUsers",
        "cognito-idp:ListUsersInGroup",
        "dax:BatchGetItem",
        "dax:GetItem",
        "dax:Query",
        "dax:Scan",
        "dynamodb:BatchGetItem",
        "dynamodb:GetItem",
        "dynamodb:GetRecords",
        "dynamodb:PartiQLSelect",
        "dynamodb:Query",
        "dynamodb:ReadDataForReplication",
        "dynamodb:Scan",
        "dynamodb:SearchVectors",
        "ec2:DescribeInstanceAttribute",
        "ec2:GetConsoleOutput",
        "ec2:GetConsoleScreenshot",
        "ec2:GetLaunchTemplateData",
        "ec2:GetPasswordData",
        "ecr-public:GetAuthorizationToken",
        "ecr:BatchGetImage",
        "ecr:GetAuthorizationToken",
        "ecr:GetDownloadUrlForLayer",
        "es:ESHttpGet",
        "es:ESHttpHead",
        "kinesis:GetRecords",
        "kms:Decrypt",
        "lambda:GetFunction",
        "lambda:GetFunctionConfiguration",
        "qldb:GetBlock",
        "qldb:GetRevision",
        "rds-data:BatchExecuteStatement",
        "rds-data:ExecuteSql",
        "rds-data:ExecuteStatement",
        "rds-db:connect",
        "redshift-data:GetStatementResult",
        "s3-object-lambda:GetObject",
        "s3-object-lambda:GetObjectVersion",
        "s3-outposts:GetObject",
        "s3-outposts:GetObjectVersion",
        "s3:GetObject",
        "s3:GetObjectTorrent",
        "s3:GetObjectVersion",
        "s3:GetObjectVersionForReplication",
        "s3:GetObjectVersionTorrent",
        "s3express:CreateSession",
        "s3tables:GetTableData",
        "s3vectors:GetVectors",
        "s3vectors:QueryVectors",
        "secretsmanager:BatchGetSecretValue",
        "secretsmanager:GetSecretValue",
        "sqs:ReceiveMessage",
        "ssm:GetParameter",
        "ssm:GetParameterHistory",
        "ssm:GetParameters",
        "ssm:GetParametersByPath",
        "states:DescribeExecution",
        "states:GetExecutionHistory",
      ],
      flatten([
        for s in jsondecode(aws_iam_role_policy.deny_data_reads.policy).Statement : flatten([s.Action])
        if s.Effect == "Deny" && s.Resource == "*"
      ])
    )) == 0
    error_message = "Every data read must be denied on all resources."
  }

  assert {
    condition = length(setsubtract(
      ["eks:AccessKubernetesApi", "ssm:SendCommand", "ssm:StartSession", "sts:AssumeRole", "sts:GetFederationToken"],
      flatten([
        for s in jsondecode(aws_iam_role_policy.deny_data_reads.policy).Statement : flatten([s.Action])
        if s.Effect == "Deny" && s.Resource == "*"
      ])
    )) == 0
    error_message = "Every escalation action must be denied on all resources."
  }

  assert {
    condition = length([
      for s in jsondecode(aws_iam_role_policy.deny_data_reads.policy).Statement : s
      if s.Effect == "Deny" && flatten([s.Action]) == ["apigateway:GET"] && sort(flatten([s.Resource])) == sort(["arn:aws:apigateway:*::/apikeys", "arn:aws:apigateway:*::/apikeys/*", "arn:aws:apigateway:*::/usageplans/*/keys", "arn:aws:apigateway:*::/usageplans/*/keys/*"])
    ]) == 1
    error_message = "apigateway:GET must be denied on the API key and usage plan key paths, which return key values."
  }

  assert {
    condition = alltrue(flatten([
      for s in jsondecode(aws_iam_role_policy.deny_data_reads.policy).Statement : [
        for a in flatten([s.Action]) : !startswith(a, "logs:")
      ]
    ]))
    error_message = "CloudWatch Logs reads must stay allowed."
  }
}

run "exposes_the_role_arn" {
  command = apply

  variables {
    role_name = "example-investigation-role"
  }

  assert {
    condition     = aws_iam_role.investigation.name == "example-investigation-role"
    error_message = "role_name must create the role under that name."
  }

  assert {
    condition     = output.role_arn == aws_iam_role.investigation.arn
    error_message = "role_arn must expose the created role's ARN."
  }
}

run "rejects_an_account_root_principal" {
  command = plan

  variables {
    principal_arn = "arn:aws:iam::123456789012:root"
  }

  expect_failures = [var.principal_arn]
}

run "rejects_a_wildcard_principal" {
  command = plan

  variables {
    principal_arn = "arn:aws:iam::123456789012:role/*"
  }

  expect_failures = [var.principal_arn]
}
