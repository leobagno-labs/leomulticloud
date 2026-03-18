variable "aws_region" {
  description = "AWS region for the primary instance"
  type        = string
  default     = "eu-west-1"
}

variable "azure_region" {
  description = "Azure region for the secondary VM"
  type        = string
  default     = "North Europe"
}

variable "instance_type" {
  description = "AWS EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "azure_vm_size" {
  description = "Azure VM size"
  type        = string
  default     = "Standard_D2as_v7"
}

variable "app_port" {
  description = "Port the Flask/Gunicorn app listens on (injected into cloud-init)"
  type        = number
  default     = 5000
}

variable "repo_url" {
  description = "Git repository URL to clone onto the VM"
  type        = string
}

variable "deploy_commit" {
  description = "Git ref (branch, tag, or commit SHA) to pin the deployment to"
  type        = string
  default     = "main"
}

variable "weather_api_key" {
  description = "OpenWeatherMap API key (leave empty for mock data)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "ssh_public_key" {
  description = "SSH public key content for EC2 key pair and Azure admin user"
  type        = string
}

variable "domain_name" {
  description = "Route 53 hosted zone domain (e.g. example.com)"
  type        = string
}


# Failover tests are run at 60 / 120 / 300 seconds to isolate TTL impact on RTO.
variable "dns_ttl" {
  description = "DNS TTL in seconds — experimental variable (60, 120, or 300)"
  type        = number
  default     = 60

  validation {
    condition     = contains([60, 120, 300], var.dns_ttl)
    error_message = "dns_ttl must be one of the experimental values: 60, 120, or 300."
  }
}
