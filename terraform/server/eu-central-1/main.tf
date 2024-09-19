# General terraform config with all needed providers
terraform {
  required_providers {
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# Europe
provider "aws" {
  region = "eu-central-1"
}

# HTTP provider for IP resolution so local dev machine access is enabled
provider "http" {}
data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}