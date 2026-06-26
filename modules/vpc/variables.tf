# -----------------------------------------------------------------------------
# VPC Module - Input Variables
# -----------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC."
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster. Used for Karpenter and ELB discovery tags on subnets."
  type        = string
}

variable "nat_gateway_count" {
  description = "Number of NAT gateways to provision. Use 1 for cost savings or match AZ count for HA."
  type        = number
  default     = 1
}
