mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_region" {
    defaults = {
      name   = "eu-central-1"
      region = "eu-central-1"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/eks-cluster-autoscaler"
    }
  }

  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::123456789012:policy/eks-cluster-autoscaling"
    }
  }
}

mock_provider "helm" {}

variables {
  cluster_name            = "example"
  cluster_oidc_issuer_url = "https://oidc.eks.eu-central-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
}

run "trusts_only_the_autoscaler_service_account" {
  command = apply

  assert {
    condition     = jsondecode(aws_iam_role.this.assume_role_policy).Statement[0].Principal.Federated == "arn:aws:iam::123456789012:oidc-provider/oidc.eks.eu-central-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
    error_message = "The role must trust the cluster's OIDC provider in the current account, with the https:// scheme stripped from the issuer."
  }

  assert {
    condition     = jsondecode(aws_iam_role.this.assume_role_policy).Statement[0].Action == "sts:AssumeRoleWithWebIdentity"
    error_message = "The role must only be assumable through web identity federation."
  }

  assert {
    condition = jsondecode(aws_iam_role.this.assume_role_policy).Statement[0].Condition == {
      StringEquals = {
        "oidc.eks.eu-central-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:sub" = "system:serviceaccount:cluster-autoscaler:cluster-autoscaler-aws-cluster-autoscaler"
        "oidc.eks.eu-central-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:aud" = "sts.amazonaws.com"
      }
    }
    error_message = "The trust policy must match the sub claim exactly against the service account the chart creates, require the sts.amazonaws.com audience, and nothing else."
  }
}

run "sub_condition_follows_release_name_and_namespace" {
  command = apply

  variables {
    name      = "ca"
    namespace = "kube-system"
  }

  assert {
    condition     = jsondecode(aws_iam_role.this.assume_role_policy).Statement[0].Condition.StringEquals["oidc.eks.eu-central-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:sub"] == "system:serviceaccount:kube-system:ca-aws-cluster-autoscaler"
    error_message = "The chart names its service account <release>-aws-cluster-autoscaler in the release namespace, so the sub condition must follow both."
  }
}

run "scaling_actions_are_limited_to_owned_groups" {
  command = apply

  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_policy.this.policy).Statement :
      s.Condition == { StringEquals = { "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/example" = "owned" } }
      if length(setintersection(s.Action, ["autoscaling:SetDesiredCapacity", "autoscaling:TerminateInstanceInAutoScalingGroup"])) > 0
    ])
    error_message = "Every statement that can scale or terminate must be conditioned on this cluster's ownership tag, or the role can drain any ASG in the account."
  }

  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_policy.this.policy).Statement :
      alltrue([for a in s.Action : can(regex("^(autoscaling|ec2):Describe", a))])
      if !can(s.Condition)
    ])
    error_message = "Unconditioned statements may only grant Describe actions."
  }
}

run "installs_the_chart_with_the_irsa_role" {
  command = apply

  assert {
    condition     = helm_release.this.repository == "https://kubernetes.github.io/autoscaler" && helm_release.this.chart == "cluster-autoscaler"
    error_message = "The release must install cluster-autoscaler from the upstream chart repository."
  }

  assert {
    condition     = helm_release.this.version == var.chart_version && helm_release.this.namespace == "cluster-autoscaler" && helm_release.this.create_namespace
    error_message = "The release must use the pinned chart version and create its namespace."
  }

  assert {
    condition     = yamldecode(helm_release.this.values[0]).rbac.serviceAccount.annotations["eks.amazonaws.com/role-arn"] == aws_iam_role.this.arn
    error_message = "The chart's service account must be annotated with the IRSA role ARN."
  }

  assert {
    condition     = yamldecode(helm_release.this.values[0]).autoDiscovery.clusterName == "example" && yamldecode(helm_release.this.values[0]).awsRegion == "eu-central-1"
    error_message = "Auto-discovery must target this cluster in the current region."
  }
}
