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
  ami_id = "ami-0fab6653f0bd437c0"  # AMI ID for eu-central-1
  vpc_id = module.vpc_eu_central_1.vpc_id
}

module "ec2_instance_eu_north_1" {
  source = "./ec2_module"
  providers = {
    aws = aws.eu-north-1
  }
  subnet_id = module.vpc_eu_north_1.subnet_ids[0]
  instance_profile_name = aws_iam_instance_profile.instance.name
  region_name = "eu-north-1"
  ami_id = "ami-07770aed8130589ff"  # AMI ID for eu-north-1
  vpc_id = module.vpc_eu_north_1.vpc_id
}

module "ec2_instance_eu_west_2" {
  source = "./ec2_module"
  providers = {
    aws = aws.eu-west-2
  }
  subnet_id = module.vpc_eu_west_2.subnet_ids[0]
  instance_profile_name = aws_iam_instance_profile.instance.name
  region_name = "eu-west-2"
  ami_id = "ami-0a63027f8a02ac374"  # AMI ID for eu-west-2
  vpc_id = module.vpc_eu_west_2.vpc_id
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

# Output instance ID and public IP
output "instance_id_eu_central_1" {
  value = module.ec2_instance_eu_central_1.instance_id
}

output "public_ip_eu_central_1" {
  value = module.ec2_instance_eu_central_1.public_ip
}

output "instance_id_eu_north_1" {
  value = module.ec2_instance_eu_north_1.instance_id
}

output "public_ip_eu_north_1" {
  value = module.ec2_instance_eu_north_1.public_ip
}

output "instance_id_eu_west_2" {
  value = module.ec2_instance_eu_west_2.instance_id
}

output "public_ip_eu_west_2" {
  value = module.ec2_instance_eu_west_2.public_ip
}