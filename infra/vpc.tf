resource "aws_vpc" "nb-vpc" {
  cidr_block = var.vpc_nb.cidr_block

  tags = {
    Name = var.vpc_nb.name
  }
}

resource "aws_subnet" "nb-subnet" {
  for_each = var.subnet_nb

  vpc_id            = aws_vpc.nb-vpc.id
  cidr_block        = each.value.cidr_block
  
  
}