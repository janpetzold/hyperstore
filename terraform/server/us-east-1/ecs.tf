# North America
provider "aws" {
  region = "us-east-1"
}

# Data source to get the IAM role ARN from the central region
data "aws_iam_role" "ecs_task_execution_role" {
  provider = aws
  name     = "ecsTaskExecutionRole"
}

module "ecs_service" {
  source = "../modules/ecs_service"
  region = "us-east-1"
  ecs_task_execution_role_arn = data.aws_iam_role.ecs_task_execution_role.arn
}