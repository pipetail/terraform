region      = "eu-west-1"
name_prefix = "wg-example"

vpc_cidr = "10.0.0.0/16"
subnets = {
  public  = ["10.0.0.0/24", "10.0.1.0/24"]
  private = ["10.0.50.0/24", "10.0.51.0/24"]
}

// paste from packer
//wireguard_ami = "ami-1234567890"
