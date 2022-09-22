output "security_group_id" {
  value       = module.sg.security_group_id
  description = "main Security Group ID"
}

output "public_ip" {
  value       = module.ec2_instance.public_ip
  description = "wireguard EC2 instance public IP to be used in VPN config"
}
