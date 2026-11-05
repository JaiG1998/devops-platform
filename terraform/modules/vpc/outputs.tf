output "vpc_id" {
  description = "The ID of the provisioned VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "The IPv4 CIDR block assigned to the VPC"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "List of IDs for the public subnets across the availability zones"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of IDs for the private subnets across the availability zones (used by EKS nodes and pods)"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs deployed in the VPC (1 if single_nat_gateway is true, or one per AZ)"
  value       = aws_nat_gateway.this[*].id
}

output "nat_public_ips" {
  description = "List of Elastic IP addresses assigned to the NAT Gateways (essential for configuring external firewall allowlists)"
  value       = aws_eip.nat[*].public_ip
}

output "azs" {
  description = "List of Availability Zones utilized by the VPC subnets"
  value       = aws_subnet.public[*].availability_zone
}