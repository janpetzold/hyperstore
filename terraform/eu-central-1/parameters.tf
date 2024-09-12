# This script creates the AWS parameter store based on our .env variable values
# It basically reads the .env file and sets each line/value as a parameter.
# For now only some REDIS config needs to be overwritten.
locals {
  env_file_content = file("${path.module}/../../hyperstore-api/.env")

  # Split file content by newline
  env_lines = [for line in split("\n", local.env_file_content) : line
    if length(trimspace(line)) > 0 && !startswith(trimspace(line), "#")
  ]

  # Convert each line into a map of key-value pairs
  env_vars = { for line in local.env_lines :
    split("=", line)[0] => join("=", slice(split("=", line), 1, length(split("=", line))))
    # Ignore REDIS_PASSWORD, we don't need that on the cluster
    if !startswith(trimspace(line), "REDIS_PASSWORD")
  }
}

# resource "aws_ssm_parameter" "env_parameters" {
#   for_each = local.env_vars

#   name  = "${each.key}"
#   type  = "SecureString"
# }
