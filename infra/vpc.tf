resource "aws_vpc" "nb-vpc" {
  cidr_block = var.vpc_nb.cidr_block

  tags = {
    Name = var.vpc_nb.name
  }
}

resource "aws_subnet" "nb-subnet" {
  for_each = var.subnet

  vpc_id            = aws_vpc.nb-vpc.id
  cidr_block        = each.value.cidr_block
}

resource "aws_internet_gateway" "nb-inet-gw" {
  depends_on = [ aws_vpc.nb-vpc ] 
  vpc_id = aws_vpc.nb-vpc.id

  tags = {
    Name = "nb-inet-gw"
  }
}

resource "aws_eip" "nb-eip-nat-gw" {
  depends_on = [ aws_internet_gateway.nb-inet-gw ]

  tags = {
    Name = "nb-eip-nat-gw"
  }
}

resource "aws_nat_gateway" "nb-nat-gw" {
  depends_on = [ aws_eip.nb-eip-nat-gw ]

  allocation_id = aws_eip.nb-eip-nat-gw.id
  subnet_id     = aws_subnet.nb-subnet["public"].id
  connectivity_type = "public"

  tags = {
    Name = "nb-nat-gw"
  }
}


resource "aws_route_table" "public" {
  vpc_id = aws_vpc.nb-vpc.id

  route = {
    cidr_block = "0.0.0.0/0"

    gateway_id = aws_internet_gateway.nb-inet-gw.id
  }

  tags = {
    Name = "nb-public-route-table"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.nb-vpc.id

  route = {
    cidr_block = "0.0.0.0/0"
    
    nat_gateway_id = aws_nat_gateway.nb-nat-gw.id
  }

  tags = {
    Name = "nb-private-route-table"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id = aws.nb-subnet["public"].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  for_each = {
    for key, subnet in var.subnet :
    key => subnet 
    if subnet.type == "private"
  }

  subnet_id = aws_subnet.nb-subnet[each.key].id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "rds-access" {
  depends_on = [ aws_subnet.nb-subnet ]

  name = "rds-access"
  vpc_id = aws_vpc.nb-vpc.id

  tags = {
    Name = "rds-access"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow-rds-access" {
  security_group_id = aws_security_group.rds-access.id
  ip_protocol          = "tcp"
  from_port         = 3306
  to_port           = 3306
  cidr_ipv4 =        [vpc.nb.cidr_block]
  
}