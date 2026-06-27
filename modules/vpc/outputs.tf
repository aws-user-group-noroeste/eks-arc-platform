# -----------------------------------------------------------------------------
# VPC Module - Outputs
# -----------------------------------------------------------------------------

output "vpc_id" {
  description = "The ID of the VPC."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs."
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "List of public subnet IDs."
  value       = module.vpc.public_subnets
}

output "azs" {
  description = "List of availability zones used by the VPC subnets."
  value       = local.azs
}

output "vpc_ipv6_cidr_block" {
  description = "The IPv6 CIDR block assigned to the VPC (null when enable_ipv6 = false)."
  value       = module.vpc.vpc_ipv6_cidr_block
}
