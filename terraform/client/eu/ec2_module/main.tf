# Provider configurations
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

variable "subnet_id" {}
variable "instance_profile_name" {}
variable "region_name" {}
variable "ami_id" {}
variable "vpc_id" {}

# Security group needed to open ports 5557 and 5558 for Locust Master/Slave config. 
# Theoretically we'd only need this on Master node and not for slaves.
resource "aws_security_group" "locust_client_sg" {
  name_prefix = "locust-client-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5557
    to_port     = 5557
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5558
    to_port     = 5558
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0 
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "locust-client" {
  ami                  = var.ami_id
  instance_type        = "t3.nano"
  subnet_id            = var.subnet_id
  iam_instance_profile = var.instance_profile_name
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.locust_client_sg.id]
  tags = {
    Name = "Locust Client ${var.region_name}"
  }
}

output "instance_id" {
  value = aws_instance.locust-client.id
}

output "public_ip" {
  value = aws_instance.locust-client.public_ip
}