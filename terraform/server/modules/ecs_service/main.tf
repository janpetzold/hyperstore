# VPC for all resources
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Public Subnet needed for Internet-accessible Gateway
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/24"
  # Same availability zone is needed so NLB can find ECS
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true
}

# Private Subnet needed for ECS Fargate and Redis
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  # Same availability zone is needed so NLB can find ECS
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = false
}

# Expose VPC and Subnet for reuse in all services
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "private_subnet_id" {
  value = aws_subnet.private.id
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

# NAT Gateway for private subnet so that ECR is accessible since
# ECS needs to fetch Docker images
resource "aws_eip" "nat_eip" {
  count = 1
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip[0].id
  subnet_id     = aws_subnet.public.id
}

# Route Table for private subnet
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    gateway_id     = aws_nat_gateway.nat_gw.id
  }
}

# Route Table Association for private subnet
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
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

# ECS deployment task for docker container
resource "aws_ecs_task_definition" "hyperstore_task" {
  family                   = "hyperstore-fargate-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"

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
    # ECS shall be in private subnet together with Redis DB
    subnets         = [aws_subnet.private.id]
    security_groups = [aws_security_group.fargate_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.hyperstore_tg.arn
    container_name   = "hyperstore-app"
    container_port   = 80
  }
}

# Network Load Balancer
resource "aws_lb" "hyperstore_nlb" {
  name               = "hyperstore-nlb"
  load_balancer_type = "network"
  security_groups    = [aws_security_group.fargate_sg.id]

  subnets            = [aws_subnet.public.id]

  internal           = false # Set to true if you want an internal ALB
}

# Network Load Balancer Listener on port 80 for HTTP
# We mainly want this for test purposes to check the NLB directly, for production this has to be closed
# however HTTPS only works via DNS
resource "aws_lb_listener" "hyperstore_listener_http" {
  load_balancer_arn = aws_lb.hyperstore_nlb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.hyperstore_tg.arn
  }
}

# Network Load Balancer Listener on port 443 for HTTPS
resource "aws_lb_listener" "hyperstore_listener_https" {
  load_balancer_arn = aws_lb.hyperstore_nlb.arn
  port              = 443
  protocol          = "TLS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  certificate_arn = aws_acm_certificate.hyperstore_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.hyperstore_tg.arn
  }
}

# ACM Certificate for HTTPS imported from Cloudflare
resource "aws_acm_certificate" "hyperstore_cert" {
  private_key       = file("./keys/cloudflare-hyperstore-private.pem")
  certificate_body  = file("./keys/cloudflare-hyperstore-public.pem")
}

# NLB Target Group to direct traffic to ECS
resource "aws_lb_target_group" "hyperstore_tg" {
  name        = "hyperstore-tg"
  port        = 80
  protocol    = "TCP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
}

output "fargate_security_group_id" {
  value = aws_security_group.fargate_sg.id
  description = "The ID of the security group used by the Fargate tasks"
}

output "alb_dns_name" {
  value       = aws_lb.hyperstore_nlb.dns_name
  description = "The DNS name of the Application Load Balancer"
}

output "alb_zone_id" {
  value       = aws_lb.hyperstore_nlb.zone_id
  description = "The zone ID of the Application Load Balancer"
}