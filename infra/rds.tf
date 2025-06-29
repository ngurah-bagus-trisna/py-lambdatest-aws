resource "aws_db_subnet_group" "nb-db-subnet" {
  depends_on = [aws_subnet.nb-subnet]
  name       = "nb-db-subnet"
  subnet_ids = [
    for key, val in var.nb-subnet : aws_subnet.nb-subnet[key].id
    if val.type == "private"
  ]

  tags = {
    "Name" = "Private DB Subnet Group"
  }
}

resource "aws_db_instance" "nb-db" {
  depends_on                  = [aws_security_group.rds-access, aws_vpc_security_group_ingress_rule.allow-rds-access]
  allocated_storage           = 10
  db_name                     = "nbdb"
  engine                      = "mysql"
  instance_class              = "db.t3.micro"
  username                    = var.db_credentials.username
  manage_master_user_password = true
  publicly_accessible         = false
  vpc_security_group_ids      = [aws_security_group.rds-access.id]
  db_subnet_group_name        = aws_db_subnet_group.nb-db-subnet.name
  skip_final_snapshot         = true
}