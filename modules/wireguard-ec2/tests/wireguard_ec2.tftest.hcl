mock_provider "aws" {}

variables {
  vpc_id               = "vpc-0123456789abcdef0"
  subnet_id            = "subnet-0123456789abcdef0"
  ami_id               = "ami-0123456789abcdef0"
  port                 = 51820
  iam_instance_profile = "wireguard-vpn"
  user_data            = "#!/bin/bash\necho boot"
}

run "boots_the_given_ami_on_an_encrypted_root_volume" {
  command = apply

  assert {
    condition     = module.ec2_instance.ami == "ami-0123456789abcdef0"
    error_message = "The instance must boot exactly the AMI passed in ami_id."
  }

  assert {
    condition     = module.ec2_instance.root_block_device[0].encrypted == true
    error_message = "The root volume holds the WireGuard private key and must be encrypted."
  }

  assert {
    condition     = output.security_group_id == module.sg.id
    error_message = "security_group_id must expose the WireGuard security group."
  }

  assert {
    condition     = module.ec2_instance.security_group_id == null
    error_message = "The instance must carry only the WireGuard security group, not a second one from the ec2-instance module with open egress."
  }
}

run "create_instance_false_skips_the_instance" {
  command = apply

  variables {
    create_instance = false
  }

  assert {
    condition     = module.ec2_instance.id == null
    error_message = "create_instance = false must not create an EC2 instance."
  }

  assert {
    condition     = output.public_ip == null
    error_message = "public_ip must be null when no instance is created."
  }
}

run "rejects_a_value_that_is_not_an_ami_id" {
  command = plan

  variables {
    ami_id = "ubuntu-24.04"
  }

  expect_failures = [var.ami_id]
}

run "rejects_a_blank_instance_profile" {
  command = plan

  variables {
    iam_instance_profile = "   "
  }

  expect_failures = [var.iam_instance_profile]
}

run "rejects_blank_user_data" {
  command = plan

  variables {
    user_data = "  "
  }

  expect_failures = [var.user_data]
}
