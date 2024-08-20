# Define the AWS provider
provider "aws" {
  region = "eu-central-1"
}

# VPC with a public subnet and internet gateway
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group for ECS task
resource "aws_security_group" "fargate_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
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

# Cloudwatch
resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name = "/ecs/hyperstore-service"

  retention_in_days = 7
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
      containerPort = 8000
      hostPort      = 8000
      protocol      = "tcp"
    }]
    logConfiguration = {
        logDriver = "awslogs"
        options = {
            "awslogs-group"         = "/ecs/hyperstore-service"
            "awslogs-region"        = "eu-central-1"
            "awslogs-stream-prefix" = "ecs"
        }
    }
  }])

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_execution_role.arn
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
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
