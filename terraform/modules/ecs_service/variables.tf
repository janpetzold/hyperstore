# Variable for defining the resion we want to deploy to - we have three currently: EU, NA, SA
variable "region" {
  description = "AWS region"
  type        = string
}

variable "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  type        = string
}