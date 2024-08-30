resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "redis-subnet-group"
  # Use parent subnet
  subnet_ids = module.ecs_service.public_subnet_ids
}

# Security group for Redis
resource "aws_security_group" "redis_sg" {
  name        = "redis-security-group"
  description = "Security group for Redis cluster"
  vpc_id      = module.ecs_service.vpc_id  // Reference to the VPC

  # Allow access from ECS services
  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    security_groups = [module.ecs_service.fargate_security_group_id]
  }

  # Allow access from local machine by whitelisting its IP
  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    # Allow acces from Bastion host
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Redis instance for EU region
resource "aws_elasticache_cluster" "eu_redis" {
  cluster_id           = "eu-redis-cluster"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis6.x"
  engine_version       = "6.x"
  port                 = 6379
  
  subnet_group_name    = aws_elasticache_subnet_group.redis_subnet_group.name
  security_group_ids   = [aws_security_group.redis_sg.id]
}

# Output the cluster host URL
output "eu_redis_cluster_host" {
  value       = aws_elasticache_cluster.eu_redis.cache_nodes[0].address
  description = "The hostname of the EU Redis cluster"
}