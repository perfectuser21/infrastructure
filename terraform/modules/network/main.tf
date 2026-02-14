# Network Module
# Manages VPN, Cloudflare Tunnels, and network configuration

terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.20.0"
    }
  }
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "servers" {
  description = "Server configurations"
  type        = map(any)
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
}

# Cloudflare Zone
data "cloudflare_zone" "main" {
  name = "zenjoymedia.media"
}

# Cloudflare Tunnel
resource "cloudflare_tunnel" "main" {
  account_id = var.cloudflare_account_id
  name       = "${var.project_name}-${var.environment}"
  secret     = random_id.tunnel_secret.b64_std
}

resource "random_id" "tunnel_secret" {
  byte_length = 32
}

# Tunnel configuration
resource "cloudflare_tunnel_config" "main" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_tunnel.main.id

  config {
    ingress_rule {
      hostname = "autopilot.zenjoymedia.media"
      service  = "http://localhost:5211"
    }

    ingress_rule {
      hostname = "dashboard.zenjoymedia.media"
      service  = "http://localhost:5211"
    }

    ingress_rule {
      hostname = "dev-autopilot.zenjoymedia.media"
      service  = "http://localhost:5212"
    }

    ingress_rule {
      hostname = "n8n.zenjoymedia.media"
      service  = "http://localhost:5679"
    }

    # Catch-all rule
    ingress_rule {
      service = "http_status:404"
    }
  }
}

# DNS Records for Tunnel
resource "cloudflare_record" "autopilot" {
  zone_id = data.cloudflare_zone.main.id
  name    = "autopilot"
  value   = "${cloudflare_tunnel.main.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_record" "dashboard" {
  zone_id = data.cloudflare_zone.main.id
  name    = "dashboard"
  value   = "${cloudflare_tunnel.main.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_record" "dev_autopilot" {
  zone_id = data.cloudflare_zone.main.id
  name    = "dev-autopilot"
  value   = "${cloudflare_tunnel.main.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_record" "n8n" {
  zone_id = data.cloudflare_zone.main.id
  name    = "n8n"
  value   = "${cloudflare_tunnel.main.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

# Firewall rules
resource "cloudflare_ruleset" "firewall" {
  zone_id = data.cloudflare_zone.main.id
  name    = "${var.project_name}-firewall"
  kind    = "zone"
  phase   = "http_request_firewall_custom"

  rules {
    action = "block"
    expression = "(cf.threat_score > 30)"
    description = "Block high threat score requests"
  }

  rules {
    action = "challenge"
    expression = "(http.request.uri.path contains \"/admin\" and ip.geoip.country ne \"US\")"
    description = "Challenge non-US admin access"
  }
}

# Port configurations (as local data)
locals {
  port_allocations = {
    # Core services
    postgresql     = 5432
    brain          = 5221
    cecelia_prod   = 5211
    cecelia_dev    = 5212
    n8n            = 5679
    claude_monitor = 3456

    # VPN
    xray_reality = 443
    xray_sub     = 8080

    # Web services
    nginx        = 80
    nginx_ssl    = 443
    npm_admin    = 81
  }
}

# Outputs
output "cloudflare_tunnel_id" {
  description = "Cloudflare Tunnel ID"
  value       = cloudflare_tunnel.main.id
}

output "cloudflare_tunnel_token" {
  description = "Cloudflare Tunnel Token"
  value       = cloudflare_tunnel.main.tunnel_token
  sensitive   = true
}

output "port_allocations" {
  description = "Port allocations for services"
  value       = local.port_allocations
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID"
  type        = string
  default     = "YOUR_ACCOUNT_ID"  # Replace with actual ID
}