packer {
  required_plugins {
    amazon = {
      version = "= 1.8.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "aws_region" {
  type = string
}

variable "ami_version" {
  type = string
}

variable "subnet_name" {
  type        = string
  description = "Name tag of a public subnet in the example VPC; the build instance needs a route to the internet"
}

variable "config_file_path" {
  type = string
}

data "amazon-ami" "ubuntu" {
  filters = {
    virtualization-type = "hvm"
    name                = "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"
    root-device-type    = "ebs"
  }
  owners      = ["099720109477"] # Canonical
  most_recent = true
}

source "amazon-ebs" "wireguard" {
  ami_name      = "wireguard-${var.ami_version}"
  ami_regions   = [var.aws_region]
  ami_users     = []
  instance_type = "t3.micro"

  encrypt_boot = true

  source_ami   = data.amazon-ami.ubuntu.id
  ssh_username = "ubuntu"

  subnet_filter {
    filters = {
      "tag:Name" = var.subnet_name
    }
  }
  associate_public_ip_address = true

  tags = {
    Name = "wireguard"
  }
}

build {
  sources = ["source.amazon-ebs.wireguard"]

  provisioner "file" {
    source      = "${var.config_file_path}"
    destination = "/tmp/wg0.conf.tftpl"
  }

  provisioner "file" {
    source      = "./configure-wireguard.sh"
    destination = "/tmp/configure-wireguard.sh"
  }

  provisioner "file" {
    source      = "./wireguard-runtime.service"
    destination = "/tmp/wireguard-runtime.service"
  }

  provisioner "shell" {
    execute_command = "sudo -S sh -c '{{ .Vars }} {{ .Path }}'"
    script          = "./prepare-system.sh"
  }
}
