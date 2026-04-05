# ─────────────────────────────────────────────
# Route 53 — DNS Failover Configuration
# Iteration 2: activated for failover testing
# ─────────────────────────────────────────────

resource "aws_route53_health_check" "primary" {
  ip_address        = aws_eip.primary.public_ip
  port              = 80
  type              = "HTTP"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 10

  tags = {
    Name    = "${var.project_name}-primary-hc"
    Project = var.project_name
  }
}

data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_record" "primary" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = var.dns_ttl

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier  = "primary"
  health_check_id = aws_route53_health_check.primary.id
  records         = [aws_eip.primary.public_ip]
}

resource "aws_route53_record" "secondary" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = var.dns_ttl

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier = "secondary"
  records        = [azurerm_public_ip.secondary.ip_address]
}
