resource "aws_db_subnet_group" "nb-db-subnet" {
  depends_on = [aws_subnet.nb-subnet]
  name       = "nb-rds-subnet-group"
  subnet_ids = [
    for subnet in aws_subnet.nb-subnet : subnet.id
    if subnet.type == "private"
  ]

  tags = {
    Name = "nb-rds-subnet-group"
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