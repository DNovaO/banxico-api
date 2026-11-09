
output "ecr_repository_url" {
  description = "URL del repositorio privado de ECR."
  value       = aws_ecr_repository.api.repository_url
}

output "ecs_cluster_name" {
  description = "Nombre del cluster ECS."
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Nombre del servicio ECS."
  value       = aws_ecs_service.api.name
}

output "ecs_task_execution_role_arn" {
  description = "ARN del rol de ejecucion ECS."
  value       = aws_iam_role.ecs_execution.arn
}

output "banxico_secret_arn" {
  description = "ARN del secreto de Banxico."
  value       = aws_secretsmanager_secret.banxico_token.arn
}

output "cloudwatch_log_group" {
  description = "Grupo de logs de la API."
  value       = aws_cloudwatch_log_group.api.name
}
