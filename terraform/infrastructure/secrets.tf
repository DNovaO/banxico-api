
resource "aws_secretsmanager_secret" "banxico_token" {
  name                    = "${var.project_name}/${var.environment}/banxico-token"
  description             = "Token de autenticacion para la API de Banxico."
  recovery_window_in_days = 7

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-banxico-token"
  })
}
