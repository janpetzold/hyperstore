# Data source to get the IAM role ARN from the central region
data "aws_iam_role" "ecs_task_execution_role" {
  provider = aws
  name     = "ecsTaskExecutionRole"
}

# ECS runtime for EU
module "ecs_service" {
  source = "../modules/ecs_service"
  region = "eu-central-1"
  ecs_task_execution_role_arn = data.aws_iam_role.ecs_task_execution_role.arn
}

