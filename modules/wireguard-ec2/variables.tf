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
  description = "AMI ID to be used with the EC2 instance. Build it with the Packer template under examples/04-aws-wireguard-vpn/packer; a stock image carries no WireGuard and the instance would come up as a bare host on a public IP."

  // Deliberately no default. This instance sits in a public subnet with a
  // public IP and 0.0.0.0/0 UDP ingress, so a default silently pins every
  // caller who omits the argument to one ageing image forever.
  validation {
    condition     = can(regex("^ami-[0-9a-f]+$", var.ami_id))
    error_message = "ami_id must be a valid AMI ID, e.g. ami-05dff77713a4fa273."
  }
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
