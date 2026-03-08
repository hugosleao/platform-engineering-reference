output "vpc_id" {
  value       = aws_vpc.main.id
  description = "ID da VPC"
}

output "vpc_cidr" {
  value       = aws_vpc.main.cidr_block
  description = "CIDR block da VPC"
}

output "public_subnet_ids" {
  value       = aws_subnet.public[*].id
  description = "IDs das subnets públicas"
}

output "private_subnet_ids" {
  value       = aws_subnet.private[*].id
  description = "IDs das subnets privadas"
}

output "nat_gateway_ids" {
  value       = var.enable_nat_gateway ? aws_nat_gateway.main[*].id : []
  description = "IDs dos NAT Gateways"
}
