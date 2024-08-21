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

resource "aws_ecs_cluster" "hyperstore_cluster" {
  name = "hyperstore-cluster"
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
  }])

  execution_role_arn = var.ecs_task_execution_role_arn
  task_role_arn      = var.ecs_task_execution_role_arn
}

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
