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
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "vpc_cidr_block" {
  value = aws_vpc.main.cidr_block
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
variable "environment_variables" {
  type = list(object({
    name  = string
    value = string
  }))
  default = []
  description = "Environment variables for the ECS task"
}

# Cloudwatch log group
resource "aws_cloudwatch_log_group" "hyperstore_logs" {
  name              = "hyperstore-node-logs"
  retention_in_days = 30  # retention period
}

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
    environment = var.environment_variables
    # Setup logs in case container fails or whatever
    logConfiguration= {
      logDriver= "awslogs",
      options= {
          awslogs-create-group= "true",
          awslogs-group= aws_cloudwatch_log_group.hyperstore_logs.name,
          awslogs-region= "eu-central-1",
          awslogs-stream-prefix= "hyperstore-logs"
      }
    }
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

# Data source to get the task details
data "aws_ecs_task" "hyperstore_task" {
  cluster = aws_ecs_cluster.hyperstore_cluster.id
  task    = aws_ecs_service.hyperstore_service.task_definition
}

# Output the public IP of the Fargate task
output "fargate_task_public_ip" {
  value = data.aws_ecs_task.hyperstore_task.network_interfaces[0].association[0].public_ip
  description = "The public IP assigned to the Fargate task"
}
