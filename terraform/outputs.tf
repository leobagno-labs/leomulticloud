output "aws_primary_ip" {
  description = "Elastic IP of the AWS primary instance (static — survives stop/start)"
  value       = aws_eip.primary.public_ip
}

output "azure_secondary_ip" {
  description = "Public IP of the Azure secondary VM"
  value       = azurerm_public_ip.secondary.ip_address
}

output "app_url" {
  description = "DNS endpoint for the application (Route 53 failover record)"
  value       = "http://app.${var.domain_name}"
}

output "aws_health_check_url" {
  description = "Direct health check URL for the AWS primary (via EIP)"
  value       = "http://${aws_eip.primary.public_ip}/health"
}

output "azure_health_check_url" {
  description = "Direct health check URL for the Azure secondary"
  value       = "http://${azurerm_public_ip.secondary.ip_address}/health"
}

output "active_dns_ttl" {
  description = "Current DNS TTL used in this deployment (experiment variable)"
  value       = var.dns_ttl
}
