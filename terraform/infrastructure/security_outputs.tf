# Identificador del Security Group asociado al ALB.
output "alb_security_group_id" {
  description = "Identificador del Security Group del ALB."
  value       = aws_security_group.alb.id
}

# Identificador del Security Group asociado a ECS.
output "ecs_security_group_id" {
  description = "Identificador del Security Group de ECS."
  value       = aws_security_group.ecs.id
}

# Identificador del NAT Gateway.
output "nat_gateway_id" {
  description = "Identificador del NAT Gateway."
  value       = aws_nat_gateway.main.id
}

# Dirección IP pública estática del NAT Gateway.
output "nat_public_ip" {
  description = "Dirección IP pública del NAT Gateway."
  value       = aws_eip.nat.public_ip
}

output "alb_id" {
  description = "Identificador del Application Load Balancer."
  value       = aws_lb.main.id
}

output "alb_dns_name" {
  description = "DNS publico del Application Load Balancer."
  value       = aws_lb.main.dns_name
}

output "alb_url" {
  description = "URL publica de la API."
  value       = "http://${aws_lb.main.dns_name}"
}

output "api_target_group_arn" {
  description = "ARN del Target Group de la API."
  value       = aws_lb_target_group.api.arn
}
