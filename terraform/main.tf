# Perfect21 Infrastructure as Code
# Main Terraform configuration

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.32.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.20.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.2"
    }
  }

  # Remote state backend (optional - can use Terraform Cloud)
  # backend "s3" {
  #   bucket = "perfect21-terraform-state"
  #   key    = "infrastructure/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

# Provider configurations
provider "digitalocean" {
  token = var.do_token
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Variables
variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment name (production, staging, development)"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "perfect21"
}

# Locals
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Repository  = "infrastructure"
  }

  servers = {
    us = {
      name       = "perfect21-us"
      region     = "nyc3"
      size       = "s-2vcpu-4gb"
      ip         = "146.190.52.84"
      tailscale  = "100.71.32.28"
    }
    hk = {
      name       = "perfect21-hk"
      region     = "sgp1"  # DigitalOcean doesn't have HK, using Singapore
      size       = "s-2vcpu-4gb"
      ip         = "43.154.85.217"
      tailscale  = "100.86.118.99"
    }
  }
}

# Modules
module "network" {
  source = "./modules/network"

  project_name = var.project_name
  environment  = var.environment
  servers      = local.servers
  tags         = local.common_tags
}

module "database" {
  source = "./modules/database"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

module "monitoring" {
  source = "./modules/monitoring"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

module "security" {
  source = "./modules/security"

  project_name     = var.project_name
  environment      = var.environment
  cloudflare_token = var.cloudflare_api_token
  tags            = local.common_tags
}

# Outputs
output "server_ips" {
  description = "Server IP addresses"
  value = {
    for k, v in local.servers : k => v.ip
  }
}

output "tailscale_ips" {
  description = "Tailscale internal IPs"
  value = {
    for k, v in local.servers : k => v.tailscale
  }
}

output "cloudflare_tunnel_id" {
  description = "Cloudflare Tunnel ID"
  value       = module.network.cloudflare_tunnel_id
}