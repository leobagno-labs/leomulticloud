data "aws_route53_zone" "main" {
  name = var.domain_name
}

#Health checks

resource "aws_route53_health_check" "primary" {
  ip_address        = aws_eip.primary.public_ip
  port              = 80
  type              = "HTTP"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30

  tags = {
    Name    = "leomulticloud-primary-hc"
    Project = "leomulticloud"
  }
}

resource "aws_route53_health_check" "secondary" {
  ip_address        = azurerm_public_ip.secondary.ip_address
  port              = 80
  type              = "HTTP"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30

  tags = {
    Name    = "leomulticloud-secondary-hc"
    Project = "leomulticloud"
  }
}

# Failover DNS records 
# TTL is the experimental variable (60 / 120 / 300 seconds).
# Changing dns_ttl and re-applying re-runs the experiment at a different TTL.

resource "aws_route53_record" "primary" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "app.${var.domain_name}"
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
  name    = "app.${var.domain_name}"
  type    = "A"
  ttl     = var.dns_ttl

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier  = "secondary"
  health_check_id = aws_route53_health_check.secondary.id
  records         = [azurerm_public_ip.secondary.ip_address]
}
