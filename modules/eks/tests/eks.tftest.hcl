mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:role/example-deployer"
    }
  }

  mock_data "aws_iam_session_context" {
    defaults = {
      issuer_arn = "arn:aws:iam::123456789012:role/example-deployer"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition  = "aws"
      dns_suffix = "amazonaws.com"
    }
  }

  mock_data "aws_eks_addon_version" {
    defaults = {
      version = "v1.0.0-eksbuild.1"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/example"
    }
  }

  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::123456789012:policy/example"
    }
  }

  mock_resource "aws_iam_openid_connect_provider" {
    defaults = {
      arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.eu-central-1.amazonaws.com/id/EXAMPLE"
    }
  }

  mock_resource "aws_launch_template" {
    defaults = {
      id = "lt-0123456789abcdef0"
    }
  }

  mock_resource "aws_eks_node_group" {
    defaults = {
      resources = [{
        autoscaling_groups              = [{ name = "eks-example-asg" }]
        remote_access_security_group_id = ""
      }]
    }
  }

  mock_resource "aws_eks_cluster" {
    defaults = {
      arn                   = "arn:aws:eks:eu-central-1:123456789012:cluster/example"
      certificate_authority = [{ data = "ZXhhbXBsZQ==" }]
      identity = [{
        oidc = [{
          issuer = "https://oidc.eks.eu-central-1.amazonaws.com/id/EXAMPLE"
        }]
      }]
    }
  }
}

mock_provider "tls" {}
mock_provider "time" {}
mock_provider "cloudinit" {}
mock_provider "null" {}

variables {
  name                           = "example"
  vpc_id                         = "vpc-0123456789abcdef0"
  control_plane_subnets          = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0aaaaaaaaaaaaaaa2"]
  worker_ami_id                  = "ami-0123456789abcdef0"
  secrets_encryption_kms_key_arn = "arn:aws:kms:eu-central-1:123456789012:key/11111111-2222-3333-4444-555555555555"
  worker_groups = [
    {
      name              = "general"
      instance_type     = "t3.large"
      asg_min_size      = 1
      asg_max_size      = 3
      target_group_arns = []
      subnets           = ["subnet-0bbbbbbbbbbbbbbb1"]
      set_taint         = false
      capacity_type     = "ON_DEMAND"
    },
    {
      name              = "ingress"
      instance_type     = "t3.medium"
      asg_min_size      = 2
      asg_max_size      = 2
      target_group_arns = ["arn:aws:elasticloadbalancing:eu-central-1:123456789012:targetgroup/example-http/0123456789abcdef", "arn:aws:elasticloadbalancing:eu-central-1:123456789012:targetgroup/example-https/0123456789abcdef"]
      subnets           = ["subnet-0bbbbbbbbbbbbbbb2"]
      set_taint         = true
      capacity_type     = "SPOT"
    },
  ]
}

run "rejects_a_worker_ami_id_that_is_not_an_ami" {
  command = plan

  variables {
    worker_ami_id = "bottlerocket-latest"
  }

  expect_failures = [var.worker_ami_id]
}

run "rejects_a_node_group_timeout_that_is_not_a_duration" {
  command = plan

  variables {
    node_group_timeouts = { create = "fifteen minutes" }
  }

  expect_failures = [var.node_group_timeouts]
}

run "accepts_a_node_group_create_timeout" {
  command = plan

  variables {
    node_group_timeouts = { create = "15m" }
  }
}

run "encrypts_secrets_with_the_provided_kms_key" {
  command = apply

  assert {
    condition     = module.eks.kms_key_arn == null
    error_message = "The upstream module must not create its own KMS key. When it does, it ignores provider_key_arn and encrypts secrets with that key instead."
  }

  assert {
    condition     = aws_kms_alias.secrets_encryption.target_key_id == var.secrets_encryption_kms_key_arn
    error_message = "The secrets encryption alias must point at the provided KMS key."
  }
}

run "creates_the_creator_and_every_listed_access_entry" {
  command = apply

  variables {
    access_entries = {
      readonly = {
        principal_arn = "arn:aws:iam::123456789012:role/example-readonly"
        policy_associations = {
          view = {
            policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
            access_scope = { type = "cluster" }
          }
        }
      }
    }
  }

  assert {
    condition     = toset(keys(module.eks.access_entries)) == toset(["cluster_creator", "readonly"])
    error_message = "With API-only authentication, access entries are the only way in. The creator entry and every entry in access_entries must be created."
  }

  assert {
    condition     = module.eks.access_entries["readonly"].principal_arn == "arn:aws:iam::123456789012:role/example-readonly"
    error_message = "access_entries must be passed through to the cluster unchanged."
  }
}

run "fans_out_one_node_group_per_worker_group" {
  command = apply

  assert {
    condition     = toset(keys(module.eks.eks_managed_node_groups)) == toset(["nodegroup0", "nodegroup1"])
    error_message = "Each worker group must become its own managed node group, keyed by list index."
  }

  assert {
    condition     = module.eks.eks_managed_node_groups["nodegroup1"].node_group_labels["nodepool"] == "ingress"
    error_message = "Each node group must be labelled with its worker group name."
  }

  assert {
    condition     = length(module.eks.eks_managed_node_groups["nodegroup0"].node_group_taints) == 0 && length(module.eks.eks_managed_node_groups["nodegroup1"].node_group_taints) == 1
    error_message = "Only worker groups with set_taint get the nodepool taint."
  }

  assert {
    condition     = toset(keys(aws_autoscaling_attachment.node_target_groups)) == toset(["nodegroup1-0", "nodegroup1-1"])
    error_message = "Each target group ARN of a worker group must be attached to that worker group's ASG, and only to it."
  }
}
