# Dirección IP pública estática que utilizará el NAT Gateway.
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-nat-eip"
  })
}

# Permite que los recursos de las subnets privadas
# establezcan conexiones salientes hacia Internet.
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  connectivity_type = "public"

  # Garantiza que el Internet Gateway exista antes
  # de crear el NAT Gateway.
  depends_on = [
    aws_internet_gateway.main
  ]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-nat"
  })
}

# Redirige el tráfico destinado a Internet desde cada
# subnet privada hacia el NAT Gateway.
resource "aws_route" "private_nat" {
  count = length(aws_route_table.private)

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}