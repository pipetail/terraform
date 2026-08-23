variable "region" {
  description = "AWS region to use with all resources"
  type        = string
  default     = "eu-west-1"
}

variable "name_prefix" {
  type        = string
  description = "name prefix to be used for unique resource names"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
}

variable "subnets" {
  description = "VPC subnets CIDRs"
  type = object({
    public  = list(string)
    private = list(string)
  })
}

variable "wireguard_ami" {
  description = "EC2 AMI that was built by packer, by default there is a fake one that will crash the terraform apply since it doesnt exist"
  default     = "ami-1234567890"
  type        = string
}

variable "wireguard_public_key" {
  description = "Public key derived from the WireGuard server private key stored in Secrets Manager"
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9+/]{43}=$", var.wireguard_public_key))
    error_message = "wireguard_public_key must be a 44-character base64 WireGuard public key."
  }
}
