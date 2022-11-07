region      = "eu-west-1"
name_prefix = "complete-example"

vpc_cidr = "10.0.0.0/16"
subnets = {
  public      = ["10.0.0.0/24", "10.0.1.0/24"]
  private     = ["10.0.50.0/24", "10.0.51.0/24"]
  database    = ["10.0.100.0/24", "10.0.101.0/24"]
  elasticache = ["10.0.150.0/24", "10.0.151.0/24"]
}

notification_emails = [
  "marek.bartik@pipetail.io"
]

retention_in_days = 30
