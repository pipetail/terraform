locals {
  # Each name is checked against the AWS Service Authorization Reference. A name IAM
  # does not know is accepted in a Deny and silently matches nothing, so a typo here
  # leaves that read open.
  denied_data_reads = [
    # S3 object contents. HeadObject is authorized as s3:GetObject, so object
    # metadata goes with it; ListBucket stays.
    "s3:GetObject",
    "s3:GetObjectTorrent",
    "s3:GetObjectVersion",
    "s3:GetObjectVersionForReplication",
    "s3:GetObjectVersionTorrent",
    "s3-object-lambda:GetObject",
    "s3-object-lambda:GetObjectVersion",
    "s3-outposts:GetObject",
    "s3-outposts:GetObjectVersion",
    "s3express:CreateSession",
    "s3tables:GetTableData",
    "s3vectors:GetVectors",
    "s3vectors:QueryVectors",

    # Parameter and secret values. ssm:DescribeParameters stays, so names and
    # versions remain readable. ReadOnlyAccess grants no Secrets Manager value or
    # KMS decrypt today; the Deny keeps a later managed-policy change from opening them.
    "ssm:GetParameter",
    "ssm:GetParameterHistory",
    "ssm:GetParameters",
    "ssm:GetParametersByPath",
    "secretsmanager:BatchGetSecretValue",
    "secretsmanager:GetSecretValue",
    "kms:Decrypt",

    # Configuration that carries environment variables and other values.
    # lambda:ListFunctions, ecs:DescribeTaskDefinition, amplify:GetApp and
    # amplify:ListBranches also return environment variables but cannot be denied
    # without losing the inventory reads.
    "amplify:GetBackendEnvironment",
    "amplify:GetBranch",
    "appconfig:GetConfiguration",
    "appconfig:GetHostedConfigurationVersion",
    "appconfig:GetLatestConfiguration",
    "codebuild:BatchGetBuildBatches",
    "codebuild:BatchGetBuilds",
    "codebuild:BatchGetProjects",
    "lambda:GetFunction",
    "lambda:GetFunctionConfiguration",
    "lambda:GetLayerVersion",

    # EC2 reads that return passwords, console output or user data.
    # ec2:DescribeLaunchTemplateVersions also returns user data but stays allowed for
    # AMI and instance type questions.
    "ec2:DescribeInstanceAttribute",
    "ec2:GetConsoleOutput",
    "ec2:GetConsoleScreenshot",
    "ec2:GetLaunchTemplateData",
    "ec2:GetPasswordData",

    # Database and table data.
    "athena:GetQueryResults",
    "athena:GetQueryResultsStream",
    "cassandra:Select",
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
    "es:ESHttpGet",
    "es:ESHttpHead",
    "qldb:GetBlock",
    "qldb:GetRevision",
    "rds-data:BatchExecuteStatement",
    "rds-data:ExecuteSql",
    "rds-data:ExecuteStatement",
    "rds-db:connect",
    "redshift-data:GetStatementResult",

    # Message payloads. sqs:ReceiveMessage also hides the message from its
    # consumers for the visibility timeout.
    "kinesis:GetRecords",
    "sqs:ReceiveMessage",
    "states:DescribeExecution",
    "states:GetExecutionHistory",

    # Container images and source code.
    "codecommit:GetBlob",
    "codecommit:GetFile",
    "codecommit:GetFolder",
    "codecommit:GitPull",
    "ecr:BatchGetImage",
    "ecr:GetAuthorizationToken",
    "ecr:GetDownloadUrlForLayer",
    "ecr-public:GetAuthorizationToken",

    # End-user records.
    "cognito-idp:AdminGetDevice",
    "cognito-idp:AdminGetUser",
    "cognito-idp:AdminListDevices",
    "cognito-idp:AdminListUserAuthEvents",
    "cognito-idp:ListUsers",
    "cognito-idp:ListUsersInGroup",

    # Knowledge base and agent memory content.
    "bedrock:AgenticRetrieveStream",
    "bedrock:GetAgentMemory",
    "bedrock:GetDocumentContent",
    "bedrock:Retrieve",
    "bedrock-agentcore:GetEvent",
    "bedrock-agentcore:GetMemoryRecord",
    "bedrock-agentcore:ListEvents",
    "bedrock-agentcore:ListMemoryRecords",
    "bedrock-agentcore:RetrieveMemoryRecords",
  ]

  # ReadOnlyAccess grants none of these today.
  denied_escalation = [
    "eks:AccessKubernetesApi",
    "ssm:SendCommand",
    "ssm:StartSession",
    "sts:AssumeRole",
    "sts:GetFederationToken",
  ]
}

resource "aws_iam_role" "investigation" {
  name                 = var.role_name
  description          = "Read-only role pipetail assumes to investigate this account, without access to stored data"
  max_session_duration = 3600

  # The session name condition makes every call show up in CloudTrail under
  # that name. It is attribution, not access control: the principal picks it.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = var.principal_arn
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:RoleSessionName" = "gate-host-agent"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "read_only" {
  role       = aws_iam_role.investigation.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "deny_data_reads" {
  name = "PipetailInvestigationDenyDataReads"
  role = aws_iam_role.investigation.id

  # An explicit Deny wins over the Allow in ReadOnlyAccess. AWS adds actions to
  # ReadOnlyAccess over time, so a new data read stays allowed until it is listed here.
  # CloudWatch Logs reads are not denied: they are the main input of an investigation.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyDataReads"
        Effect   = "Deny"
        Action   = local.denied_data_reads
        Resource = "*"
      },
      {
        Sid      = "DenyEscalation"
        Effect   = "Deny"
        Action   = local.denied_escalation
        Resource = "*"
      },
      {
        # API Gateway authorizes reads by HTTP verb and path. GET on /apikeys and on
        # a usage plan's /keys returns the key values.
        Sid    = "DenyApiKeyReads"
        Effect = "Deny"
        Action = "apigateway:GET"
        Resource = [
          "arn:aws:apigateway:*::/apikeys",
          "arn:aws:apigateway:*::/apikeys/*",
          "arn:aws:apigateway:*::/usageplans/*/keys",
          "arn:aws:apigateway:*::/usageplans/*/keys/*",
        ]
      }
    ]
  })
}
