
resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 14

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-logs"
  })
}
