resource "aws_db_subnet_group" "app" {
  name       = format("%s-db-subnets", local.app_name)
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tags = {
    Name    = format("%s-db-subnets", local.app_name)
    Project = local.project
  }
}

resource "aws_security_group" "db" {
  name        = format("%s-db-sg", local.app_name)
  description = "Aurora Postgres access from within the VPC"
  vpc_id      = aws_vpc.app.id

  ingress {
    description = "Postgres from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.app.cidr_block]
  }

  tags = {
    Name    = format("%s-db-sg", local.app_name)
    Project = local.project
  }
}

resource "random_password" "db_master" {
  length  = 24
  special = false
}

resource "aws_db_instance" "app" {
  identifier             = format("%s-postgres", local.app_name)
  engine                 = "postgres"
  engine_version         = "17.9"
  instance_class         = "db.t4g.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  storage_encrypted      = true
  db_name                = "demo"
  username               = "masteruser"
  password               = random_password.db_master.result
  db_subnet_group_name   = aws_db_subnet_group.app.name
  vpc_security_group_ids = [aws_security_group.db.id]
  multi_az               = false
  publicly_accessible    = false
  skip_final_snapshot    = true

  tags = {
    Name    = format("%s-postgres", local.app_name)
    Project = local.project
  }
}
