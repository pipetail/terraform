locals {
  loki_container_definitions = jsonencode([
    {
      image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/grafana:loki-2.6.1-arm64"
      name  = "loki"
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.loki.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "loki"
        }
      },
      essential = true,
      portMappings = [
        {
          hostPort      = 3100
          containerPort = 3100
          protocol      = "tcp"
        }
      ]
    }
  ])
}

resource "aws_cloudwatch_log_group" "loki" {
  #checkov:skip=CKV_AWS_158: We don't encrypt the log group yet TODO: we should
  #checkov:skip=CKV_AWS_338: Retention is configurable via variable, default is acceptable for example code
  name = "loki"

  retention_in_days = var.retention_in_days
}

resource "aws_service_discovery_private_dns_namespace" "loki" {
  name        = "grafana.local"
  description = "Service discovery local domain for grafana loki"
  vpc         = module.vpc.vpc_id
}

resource "aws_service_discovery_service" "loki" {
  name = "loki"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.loki.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }
}

resource "aws_ecs_task_definition" "loki" {
  #checkov:skip=CKV_AWS_336: Read-only filesystem not configured for this example
  family = "loki_task_definition"

  container_definitions = local.loki_container_definitions

  runtime_platform {
    cpu_architecture = "ARM64"
  }

  requires_compatibilities = ["FARGATE"]
  cpu                      = 4096
  memory                   = 8192
  task_role_arn            = aws_iam_role.loki_ecs_task.arn
  execution_role_arn       = aws_iam_role.loki_ecs_task_execution.arn
  network_mode             = "awsvpc"
}

resource "aws_ecs_service" "loki" {
  name            = "loki"
  cluster         = aws_ecs_cluster.grafana.name
  task_definition = aws_ecs_task_definition.loki.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  enable_execute_command = true

  network_configuration {
    security_groups = [module.sg_loki.security_group_id]
    subnets         = module.vpc.private_subnets
  }

  service_registries {
    registry_arn = aws_service_discovery_service.loki.arn
  }
}

module "sg_loki" {
  #checkov:skip=CKV_TF_1:Using registry versioned modules
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.3.1"

  name        = "loki"
  description = "Security group for grafana loki ECS"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    # {
    #   description              = "Loki access from grafana"
    #   from_port                = 3100
    #   to_port                  = 3100
    #   protocol                 = "tcp"
    #   source_security_group_id = module.sg_grafana.security_group_id
    # },
    # {
    #   description              = "Loki log push"
    #   from_port                = 3100
    #   to_port                  = 3100
    #   protocol                 = "tcp"
    #   source_security_group_id = // add here your app sg id
    # },
  ]

  egress_with_cidr_blocks = [{
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = "0.0.0.0/0"
    description = "Allow outgoing traffic"
  }]
}

resource "aws_iam_role" "loki_ecs_task_execution" {
  name = "loki-ecs-task-execution"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowECSTasksToAssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "loki_ecs_task_execution" {
  role       = aws_iam_role.loki_ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "loki_ecs_task_execution" {
  name = "loki-ecs-task-execution"
  role = aws_iam_role.loki_ecs_task_execution.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowECSToAuthenticateToECRInCentralAccount"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = ["*"]
      },
      {
        Sid    = "AllowECSToPullImage"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
        ]
        Resource = [aws_ecr_repository.grafana.arn]
      },
      {
        Sid    = "AllowECSToWriteLogsToCloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
        ]
        Resource = [aws_cloudwatch_log_group.loki.arn]
      },
    ]
  })
}

resource "aws_iam_role" "loki_ecs_task" {
  name = "loki-ecs-task"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowECSTasksToAssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "loki_storage" {
  name = "loki-storage-access"
  role = aws_iam_role.loki_ecs_task.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowLokiStorageChunksS3"
      Effect = "Allow"
      Action = [
        "s3:ListBucket",
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
      ]
      Resource = [
        module.loki_storage.s3_bucket_arn,
        "${module.loki_storage.s3_bucket_arn}/*",
      ]
    }]
  })
}

resource "aws_iam_role_policy" "loki_ecs_task_command_exec" {
  #checkov:skip=CKV_AWS_290:SSM and logs actions require wildcard resources for ECS Exec
  #checkov:skip=CKV_AWS_355:SSM and logs actions require wildcard resources for ECS Exec
  name   = "loki-ecs-command-exec"
  role   = aws_iam_role.loki_ecs_task.name
  policy = local.allow_command_exec_policy
}

module "loki_storage" {
  #checkov:skip=CKV_TF_1:Using registry versioned modules
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.11.0"

  bucket = "${var.name_prefix}-loki-data"

  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  versioning = {
    enabled = false
  }

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
