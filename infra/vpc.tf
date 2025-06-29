resource "aws_vpc" "nb-vpc" {
  cidr_block = var.vpc_nb.cidr_block

  tags = {
    Name = var.vpc_nb.name
  }
}

resource "aws_subnet" "nb-subnet" {
  for_each = var.nb-subnet

  vpc_id                  = aws_vpc.nb-vpc.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.az
  map_public_ip_on_launch = each.value.type == "public" ? true : false

  tags = {
    Name = "${var.vpc_nb.name}-${each.key}"
    Type = each.value.type
  }
}

resource "aws_internet_gateway" "nb-inet-gw" {
  depends_on = [aws_vpc.nb-vpc]
  vpc_id     = aws_vpc.nb-vpc.id

  tags = {
    Name = "nb-inet-gw"
  }
}

resource "aws_eip" "nb-eip-nat-gw" {
  depends_on = [aws_internet_gateway.nb-inet-gw]

  tags = {
    Name = "nb-eip-nat-gw"
  }
}

resource "aws_nat_gateway" "nb-nat-gw" {
  depends_on = [aws_eip.nb-eip-nat-gw]

  allocation_id     = aws_eip.nb-eip-nat-gw.id
  subnet_id         = aws_subnet.nb-subnet["public-net"].id
  connectivity_type = "public"

  tags = {
    Name = "nb-nat-gw"
  }
}


resource "aws_route_table" "public" {
  depends_on = [aws_subnet.nb-subnet, aws_internet_gateway.nb-inet-gw]
  vpc_id     = aws_vpc.nb-vpc.id

  route {
    cidr_block = "0.0.0.0/0"

    gateway_id = aws_internet_gateway.nb-inet-gw.id
  }

  tags = {
    Name = "nb-public-route-table"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.nb-vpc.id

  route {
    cidr_block = "0.0.0.0/0"

    nat_gateway_id = aws_nat_gateway.nb-nat-gw.id
  }

  tags = {
    Name = "nb-private-route-table"
  }
}

resource "aws_route_table_association" "public" {
  depends_on     = [aws_subnet.nb-subnet, aws_route_table.public]
  subnet_id      = aws_subnet.nb-subnet["public-net"].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  for_each = {
    for key, subnet in var.nb-subnet :
    key => subnet
    if subnet.type == "private"
  }

  subnet_id      = aws_subnet.nb-subnet[each.key].id
  route_table_id = aws_route_table.private.id
}

resource "aws_db_subnet_group" "nb-rds-subnet-group" {
  name = "nb-rds-subnet-group"
  subnet_ids = [
    for key, val in var.nb-subnet :
    aws_subnet.nb-subnet[key].id
    if val.type == "private"
  ]

  tags = {
    Name = "nb-rds-subnet-group"
  }

}

resource "aws_security_group" "rds-access" {
  depends_on = [aws_subnet.nb-subnet]

  name   = "rds-access"
  vpc_id = aws_vpc.nb-vpc.id

  tags = {
    Name = "rds-access"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow-rds-access" {
  security_group_id = aws_security_group.rds-access.id
  ip_protocol       = "tcp"
  from_port         = 3306
  to_port           = 3306
  cidr_ipv4         = aws_vpc.nb-vpc.cidr_block

}

resource "aws_security_group" "web-sg" {
  depends_on = [aws_subnet.nb-subnet]

  name        = "web-sg"
  description = "Security group to allow access port 22"
  vpc_id      = aws_vpc.nb-vpc.id

  tags = {
    "Name" : "web-server-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow-access-ssh" {
  depends_on = [aws_security_group.web-sg]

  security_group_id = aws_security_group.web-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  to_port           = 22
  from_port         = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "allow-access-public" {
  depends_on        = [aws_security_group.web-sg]
  security_group_id = aws_security_group.web-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # -1 means all protocols
}