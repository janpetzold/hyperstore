# Provider configurations
provider "aws" {
  alias  = "eu-central-1"
  region = "eu-central-1"
}

provider "aws" {
  alias  = "eu-north-1"
  region = "eu-north-1"
}

provider "aws" {
  alias  = "eu-west-2"
  region = "eu-west-2"
}

# VPC and subnet definitions for each region
module "vpc_eu_central_1" {
  source = "./vpc_module"
  providers = {
    aws = aws.eu-central-1
  }
  region_name = "eu-central-1"
  availability_zones = ["eu-central-1a"]
}

module "vpc_eu_north_1" {
  source = "./vpc_module"
  providers = {
    aws = aws.eu-north-1
  }
  region_name = "eu-north-1"
  availability_zones = ["eu-north-1a"]
}

module "vpc_eu_west_2" {
  source = "./vpc_module"
  providers = {
    aws = aws.eu-west-2
  }
  region_name = "eu-west-2"
  availability_zones = ["eu-west-2a"]
}

# Client VMs for each region
module "ec2_instance_eu_central_1" {
  source = "./ec2_module"
  providers = {
    aws = aws.eu-central-1
  }
  subnet_id = module.vpc_eu_central_1.subnet_ids[0]
  instance_profile_name = aws_iam_instance_profile.instance.name
  region_name = "eu-central-1"
  ami_id = "ami-01281875f5855b6d6"  # AMI ID for eu-central-1
}

module "ec2_instance_eu_north_1" {
  source = "./ec2_module"
  providers = {
    aws = aws.eu-north-1
  }
  subnet_id = module.vpc_eu_north_1.subnet_ids[0]
  instance_profile_name = aws_iam_instance_profile.instance.name
  region_name = "eu-north-1"
  ami_id = "ami-01eb185b7fca4eeac"  # AMI ID for eu-north-1
}

module "ec2_instance_eu_west_2" {
  source = "./ec2_module"
  providers = {
    aws = aws.eu-west-2
  }
  subnet_id = module.vpc_eu_west_2.subnet_ids[0]
  instance_profile_name = aws_iam_instance_profile.instance.name
  region_name = "eu-west-2"
  ami_id = "ami-084054325f473473c"  # AMI ID for eu-west-2
}

# IAM role and instance profile (defined once, used across regions)
resource "aws_iam_instance_profile" "instance" {
  provider = aws.eu-central-1
  name = "locust-client-profile"
  role = aws_iam_role.instance.name
}

resource "aws_iam_role" "instance" {
  provider = aws.eu-central-1
  name        = "locust-client-role"
  description = "Role for Locust Client"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      },
    ]
  })

  tags = {
    Name = "Locust Client Role"
  }
}

resource "aws_iam_role_policy_attachment" "instance" {
  provider   = aws.eu-central-1
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.instance.name
}

# Outputs
output "instance_id_eu_central_1" {
  value = module.ec2_instance_eu_central_1.instance_id
}

output "instance_id_eu_north_1" {
  value = module.ec2_instance_eu_north_1.instance_id
}

output "instance_id_eu_west_2" {
  value = module.ec2_instance_eu_west_2.instance_id
}