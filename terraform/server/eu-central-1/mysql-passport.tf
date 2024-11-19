variable "mysql_password" {
  description = "Password for MySQL RDS instance"
  type        = string
  sensitive   = true
}

resource "aws_db_instance" "mysql_instance" {
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "8.0"
  # Small instance allows ~ 150 connections, micro is not enough here
  instance_class       = "db.t3.small"
  db_name              = "passportdb"
  username             = "passport"
  password             = var.mysql_password
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = true

  vpc_security_group_ids = [aws_security_group.mysql_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.mysql_subnet_group.name

  # Ensure the RDS instance is in the same VPC
  publicly_accessible = false
}

# AWS RDS requires multiple subnets in different AZs
resource "aws_subnet" "subnet_b" {
  vpc_id            = module.ecs_service.vpc_id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-central-1b"
}

resource "aws_db_subnet_group" "mysql_subnet_group" {
  name       = "mysql-subnet-group"
  subnet_ids = [module.ecs_service.private_subnet_id, aws_subnet.subnet_b.id]

  tags = {
    Name = "HyperstoreMySQLSubnetGroup"
  }
}

resource "aws_security_group" "mysql_sg" {
  name        = "mysql_sg"
  description = "Allow MySQL traffic"
  vpc_id      = module.ecs_service.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    # Allow access from all nodes in same VPC (essentially Bastion host and Fargate)
    cidr_blocks = [module.ecs_service.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "rds_endpoint" {
  value = aws_db_instance.mysql_instance.endpoint
  description = "The endpoint of the Passport RDS instance"
}