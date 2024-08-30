# VPC for all resources
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Public Subnet needed for ECS Fargate
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

# Expose VPC and Subnet for reuse in all services
output "vpc_id" {
  value       = aws_vpc.main.id
  description = "ID of the VPC"
}

output "public_subnet_ids" {
  value       = aws_subnet.public[*].id
  description = "IDs of the public subnets"
}

# Internet Gateway for public subnet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# Route Table for public subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Route Table Association for public subnet needed for ECS Fargate
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group for Fargate
resource "aws_security_group" "fargate_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
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

# ECS Cluster
resource "aws_ecs_cluster" "hyperstore_cluster" {
  name = "hyperstore-cluster"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "hyperstore_task" {
  family                   = "hyperstore-fargate-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([{
    name  = "hyperstore-app"
    image = "290562283841.dkr.ecr.eu-central-1.amazonaws.com/hyperstore-repo:latest"
    portMappings = [{
      containerPort = 80
      hostPort      = 80
      protocol      = "tcp"
    }]
  }])

  execution_role_arn = var.ecs_task_execution_role_arn
  task_role_arn      = var.ecs_task_execution_role_arn
}

# ECS Service
resource "aws_ecs_service" "hyperstore_service" {
  name            = "hyperstore-service"
  cluster         = aws_ecs_cluster.hyperstore_cluster.id
  task_definition = aws_ecs_task_definition.hyperstore_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1
  enable_execute_command = true

  network_configuration {
    subnets         = [aws_subnet.public.id]
    security_groups = [aws_security_group.fargate_sg.id]
    assign_public_ip = true
  }
}

output "fargate_security_group_id" {
  value = aws_security_group.fargate_sg.id
  description = "The ID of the security group used by the Fargate tasks"
}
