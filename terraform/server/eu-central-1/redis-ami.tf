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
  instance_type = "t2.micro"
  
  vpc_security_group_ids = [aws_security_group.redis_hyperstore_sg.id]
  subnet_id              = module.ecs_service.private_subnet_id
  private_ip = "10.0.1.12"

  tags = {
    Name = "RedisInstance"
  }
}

# Assign Elastic IP
resource "aws_eip_association" "redis_association" {
  instance_id = aws_instance.redis_instance.id
  allocation_id = "eipalloc-0c71fff45151a0e3a"
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
    # Allow access from all machines in same subnet 
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