
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-cluster"
  })
}

# ECS Task Definition
resource "aws_ecs_task_definition" "api" {
  family                   = "${var.project_name}-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  cpu    = "256"
  memory = "512"

  execution_role_arn = aws_iam_role.ecs_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = "${aws_ecr_repository.api.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "BANXICO_BASE_URL"
          value = "https://www.banxico.org.mx/SieAPIRest/service/v1"
        },
        {
          name  = "REQUEST_TIMEOUT_SECONDS"
          value = "10"
        },
        {
          name  = "CACHE_TTL_SECONDS"
          value = "300"
        },
        {
          name  = "LOG_LEVEL"
          value = "INFO"
        }
      ]

      secrets = [
        {
          name      = "BANXICO_TOKEN"
          valueFrom = aws_secretsmanager_secret.banxico_token.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.api.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "api"
        }
      }

      stopTimeout = 30
    }
  ])

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-task"
  })
}

# ECS Fargate Service
resource "aws_ecs_service" "api" {
  name            = "${var.project_name}-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn

  desired_count = 0
  launch_type   = "FARGATE"

  platform_version                  = "LATEST"
  enable_execute_command            = false
  health_check_grace_period_seconds = 60

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = 8000
  }

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy_attachment.ecs_execution_managed,
    aws_iam_role_policy.ecs_secret_access
  ]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-service"
  })
}
