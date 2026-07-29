data "aws_caller_identity" "current" {}

provider "aws" {
  region = var.region
}

provider "aws" {
  region = "us-east-1"
  alias  = "virginia"
}

data "aws_eks_cluster" "main" {
  name       = module.eks.cluster_name
  depends_on = [module.eks.cluster_name]
}

data "aws_eks_cluster_auth" "main" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}

terraform {
  required_version = ">= 1.11.0"

  backend "s3" {
    bucket       = "pipetail-examples-terraform-state"
    key          = "05-aws-complete"
    region       = "eu-west-1"
    use_lockfile = true
    encrypt      = true
  }

  required_providers {
    # terraform-aws-modules/eks 21.24.0 requires >= 6.52; an exact pin here went
    # unsatisfiable the moment that module was bumped. Track 6.x instead so a
    # module bump within the major cannot break init again.
    # 6.57.0 fails every data.aws_caller_identity read with "reading STS Caller
    # Identity ... StatusCode: 302, api error UnknownError". Reproduces on a bare
    # config of four such data sources; 6.55.0 and 6.56.0 are fine. Drop the
    # exclusion once a later release is confirmed good.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.52, != 6.57.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.9.0"
    }
  }
}
