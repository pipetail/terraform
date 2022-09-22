variable "vpc_id" {
  description = "ID of the VPC where to create all the resources"
  type        = string
}

variable "subnet_id" {
  description = "VPC Subnet ID to be used with the AWS resources, mainly EC2 instance"
  type        = string
}

variable "create_instance" {
  type        = bool
  description = "Whether or not to create an EC2 instance to run the wireguard"
  default     = true
}

variable "ami_id" {
  type        = string
  description = "AMI ID to be used with the EC2 instance"
  default     = "ami-08ca3fed11864d6bb" // ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-20211129
}

variable "ssh_key_name" {
  type        = string
  description = "SSH key name to be used with the EC2 instance"
  default     = ""
}

variable "port" {
  type        = number
  description = "wireguard UDP port"
}
