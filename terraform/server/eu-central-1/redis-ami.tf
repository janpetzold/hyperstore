# 
# This is an AMI-based Redis DB. It is based on a recent Ubuntu image and has a basic Redis
# instance running. This approach was chosen for two reasons:
#
# 1. The apply/destroy of Elasticache Redis instance was incredibly slow, it sometimes 
#    took 10 minutes to create/destroy the instance whereas the VM is available in a few seconds.
# 2. I failed to connect ECS/Fargate with Elasticache, some kind of security problem 
#    I was not able to fix preventing any connection
#

resource "aws_instance" "redis_instance" {
  ami           = "ami-0c68c16f694e0e248"
  instance_type = "t3.small"
  
  vpc_security_group_ids = [aws_security_group.redis_hyperstore_sg.id]
  subnet_id              = module.ecs_service.private_subnet_id
  private_ip = "10.0.1.12"

  # Bastion SSH key shall also work for SSHing into Redis instance
  key_name = aws_key_pair.generated_key.key_name

  tags = {
    Name = "RedisInstance"
  }
}

resource "aws_security_group" "redis_hyperstore_sg" {
  name        = "redis_hyperstore_sg"
  description = "Allow Redis traffic"
  vpc_id      = module.ecs_service.vpc_id

  # Allow ingress from all machines in the same subnet
  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    # Allow access from all machines in same VPC (essentially Bastion host and Fargate) 
    cidr_blocks = [module.ecs_service.vpc_cidr_block]
  }

  # Allow access from my local IP
  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# All following definitions are for Bastion jumphost so
# Redis DB can be accessed from local environment even if no SSH port is open
# and DB remains in private network

# Define SSH key
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "bastion-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# Bastion host needs to allow port 22 but only from cuurent machine
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Allow SSH access to bastion host"
  vpc_id      = module.ecs_service.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 definition of Bastion host
resource "aws_instance" "bastion_host" {
  ami           = "ami-0c68c16f694e0e248" # Ubuntu 22.04 LTS
  instance_type = "t3.nano"
  subnet_id     = module.ecs_service.public_subnet_id
  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.bastion_sg.id]

  key_name = aws_key_pair.generated_key.key_name

  tags = {
    Name = "BastionHost"
  }
}

# Enable access for Bastion to Redis DB via port 22 / Bastion security group
resource "aws_security_group_rule" "allow_bastion_to_redis" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion_sg.id
  security_group_id        = aws_security_group.redis_hyperstore_sg.id
}

# Save private SSH key for Bastion access locally
resource "local_file" "ssh_key" {
  content  = tls_private_key.ssh_key.private_key_pem
  filename = "bastion-key.pem"
}

output "bastion_public_ip" {
  description = "Public IP address of the bastion host"
  value       = aws_instance.bastion_host.public_ip
}