# A Bastion host is set up so we can work with the Elasticacche Redis
# DB also from locl development environment. Public internet access to Elasticache
# is generally nit possible, therefore this is the best way.
provider "tls" {}

# Get latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

output "ami_id" {
  value = data.aws_ami.amazon_linux_2.id
}

# Generate keypair
resource "tls_private_key" "bastion_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.bastion_ssh.private_key_pem
  filename        = "${path.module}/bastion_ssh_key.pem"
  file_permission = "0600"
}

output "bastion_private_key_path" {
  value       = local_file.private_key.filename
  description = "Path to the bastion host's private SSH key"
}

resource "aws_key_pair" "bastion" {
  key_name   = "bastion-key"
  public_key = tls_private_key.bastion_ssh.public_key_openssh
}

# Setup Bastion EC2 instance
resource "aws_instance" "bastion" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.bastion.key_name

  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  subnet_id              = module.ecs_service.public_subnet_ids[0]  # Use a public subnet

  tags = {
    Name = "Bastion Host for Hyper Redis"
  }
}

# HTTP provider for IP resolution so Redis is enabled for local dev machine access
provider "http" {}
data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

resource "aws_security_group" "bastion_sg" {
  name        = "bastion-security-group"
  description = "Security group for Bastion host"
  vpc_id      = module.ecs_service.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]  # Your IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "bastion_ssh_command" {
  value = "ssh -i ${local_file.private_key.filename} ec2-user@${aws_instance.bastion.public_ip}"
  description = "SSH command to connect to the bastion host"
}