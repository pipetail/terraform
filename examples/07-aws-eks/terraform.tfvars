region      = "eu-west-1"
name_prefix = "eks-e2e"

vpc_cidr = "10.70.0.0/16"
subnets = {
  public  = ["10.70.0.0/24", "10.70.1.0/24"]
  private = ["10.70.50.0/24", "10.70.51.0/24"]
}

k8s_version = "1.36"
