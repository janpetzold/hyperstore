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
  # Use AWS parameters since we have no .env
  environment_variables = [
    for key, value in aws_ssm_parameter.env_parameters : {
      name  = key
      value = value.value
    }
  ]
}

# Export our VPC ID so we're sure to use the same for Redis security group config
output "ecs_vpc_id" {
  value = module.ecs_service.vpc_id
}

