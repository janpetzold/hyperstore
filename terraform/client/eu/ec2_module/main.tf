variable "subnet_id" {}
variable "instance_profile_name" {}
variable "region_name" {}
variable "ami_id" {}

resource "aws_instance" "locust-client" {
  ami                  = var.ami_id
  instance_type        = "t3.nano"
  subnet_id            = var.subnet_id
  iam_instance_profile = var.instance_profile_name
  associate_public_ip_address = true
  tags = {
    Name = "Locust Client ${var.region_name}"
  }
}

output "instance_id" {
  value = aws_instance.locust-client.id
}