terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"  # Use the version you prefer
    }
  }
}

# Use the aws provider
provider "aws" {}

variable "region_name" {}
variable "availability_zones" {
  type = list(string)
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "main-vpc-${var.region_name}"
  }
}

resource "aws_subnet" "main" {
  count             = 1
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.availability_zones[0]
  map_public_ip_on_launch = true
  
  tags = {
    Name = "main-subnet-${var.region_name}"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw-${var.region_name}"
  }
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "main-route-table-${var.region_name}"
  }
}

resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main[0].id
  route_table_id = aws_route_table.main.id
}

output "subnet_ids" {
  value = aws_subnet.main[*].id
}