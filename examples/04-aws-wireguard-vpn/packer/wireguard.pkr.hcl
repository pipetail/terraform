packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
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

variable "subnet_id" {
  type = string
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

data "amazon-secretsmanager" "wireguard_keys" {
  name = "wireguard"
  key  = "private_key"
}

source "amazon-ebs" "wireguard" {
  ami_name      = "wireguard-${var.ami_version}"
  ami_regions   = [var.aws_region]
  ami_users     = []
  instance_type = "t3.micro"

  source_ami   = data.amazon-ami.ubuntu.id
  ssh_username = "ubuntu"

  subnet_id = var.subnet_id

  tags = {
    Name = "wireguard"
  }
}

build {
  sources = ["source.amazon-ebs.wireguard"]

  provisioner "file" {
    source      = "${var.config_file_path}"
    destination = "/tmp/wg0.conf.tpl"
  }

  provisioner "shell" {
    environment_vars = [
      "PRIVATE_KEY=${data.amazon-secretsmanager.wireguard_keys.value}",
    ]
    execute_command = "sudo -S sh -c '{{ .Vars }} {{ .Path }}'"
    script          = "./prepare-system.sh"
  }
}
