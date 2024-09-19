provider "aws" {
  region = "eu-central-1"
}

# VPC and subnet definition needed for EC2 VM
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "main-vpc"
  }
}

resource "aws_subnet" "main" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "main-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

# Route table
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "main-route-table"
  }
}

# Route table association
resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

# Security group
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh"
  }
}


# Client VM
resource "aws_instance" "locust-client" {
    # Custom Ubuntu 24.04 LTS image with pre-installed locust as root and AWS SSM activated       
    ami           = "ami-01281875f5855b6d6"
    instance_type = "t2.nano"
    subnet_id     = aws_subnet.main.id
    iam_instance_profile = aws_iam_instance_profile.instance.name
    vpc_security_group_ids      = [aws_security_group.allow_ssh.id]
    associate_public_ip_address = true
    tags = {
      Name = "Locust EU Client"
    }
}

# Policy definition so we're able to use AWS SSM
resource "aws_iam_instance_profile" "instance" {
  name = "locust-client-profile"
  role = aws_iam_role.instance.name
}

resource "aws_iam_role" "instance" {
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
        Sid       = ""
      },
    ]
  })

  tags = {
        Name = "Locust EU Client Role"
  }
}

resource "aws_iam_role_policy_attachment" "instance" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.instance.name
}

output "locust_client_instance_id" {
  description = "The ID of the Locust client EC2 instance"
  value       = aws_instance.locust-client.id
}