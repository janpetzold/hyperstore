# This script creates the AWS parameter store based on our .env variable values
# It basically reads the .env file and sets each line/value as a parameter.
locals {
  env_file_content = file("${path.module}/../../../hyperstore-api/.env")

  # Split file content by newline. Ignore empty lines and line comments
  env_lines = [for line in split("\n", local.env_file_content) : line
    if length(trimspace(line)) > 0 && !startswith(trimspace(line), "#")
  ]

  # Convert each line into a map of key-value pairs
  env_vars = { for line in local.env_lines :
    split("=", line)[0] => join("=", slice(split("=", line), 1, length(split("=", line))))
  }
}

resource "aws_ssm_parameter" "env_parameters" {
  for_each = local.env_vars

  name  = "${each.key}"
  type  = "SecureString"
  value = each.value
}

# Output all environment variables
output "environment_variables" {
  value = local.env_vars
  description = "All environment variables stored in the AWS Parameter Store"
}
