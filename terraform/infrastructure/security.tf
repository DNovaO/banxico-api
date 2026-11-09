
# --------------------------------------------------
# Security Group del Application Load Balancer
# --------------------------------------------------

# Controla el trafico de entrada y salida del ALB.
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Controla el acceso de red al Application Load Balancer."
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-alb-sg"
  })
}

# Permite recibir solicitudes HTTP desde Internet.
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id

  description = "Allow HTTP traffic from the Internet."
  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
  cidr_ipv4   = "0.0.0.0/0"
}

# Permite que el ALB reenvie solicitudes hacia los contenedores ECS.
resource "aws_vpc_security_group_egress_rule" "alb_to_ecs" {
  security_group_id = aws_security_group.alb.id

  description                  = "Allow traffic to ECS application containers."
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
  referenced_security_group_id = aws_security_group.ecs.id
}

# --------------------------------------------------
# Security Group de ECS
# --------------------------------------------------

# Restringe el acceso de red a las tareas que ejecutan la API.
resource "aws_security_group" "ecs" {
  name        = "${var.project_name}-ecs-sg"
  description = "Controla el acceso de red a las tareas de ECS."
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ecs-sg"
  })
}

# Permite recibir trafico en el puerto de la aplicacion
# unicamente desde el Security Group del ALB.
resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id = aws_security_group.ecs.id

  description                  = "Allow application traffic exclusively from the ALB."
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
  referenced_security_group_id = aws_security_group.alb.id
}

# Permite conexiones HTTPS salientes hacia servicios externos,
# incluyendo la API del Banco de Mexico.
resource "aws_vpc_security_group_egress_rule" "ecs_https" {
  security_group_id = aws_security_group.ecs.id

  description = "Allow HTTPS outbound connections to external APIs."
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_ipv4   = "0.0.0.0/0"
}
