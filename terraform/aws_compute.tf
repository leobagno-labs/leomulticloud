data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "leomulticloud-key"
  public_key = var.ssh_public_key
}

resource "aws_security_group" "primary" {
  name        = "leomulticloud-primary-sg"
  description = "Allow HTTP (80) and SSH (22) inbound"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "leomulticloud-primary-sg"
    Project = "leomulticloud"
  }
}

resource "aws_instance" "primary" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.primary.id]

  user_data = templatefile("${path.module}/cloud-init.yaml", {
    cloud_provider  = "AWS"
    app_user        = "ubuntu"
    app_port        = var.app_port
    weather_api_key = var.weather_api_key
    repo_url        = var.repo_url
    deploy_commit   = var.deploy_commit
  })

  tags = {
    Name    = "leomulticloud-primary"
    Project = "leomulticloud"
    Role    = "primary"
  }
}

resource "aws_eip" "primary" {
  domain   = "vpc"
  instance = aws_instance.primary.id

  tags = {
    Name    = "leomulticloud-primary-eip"
    Project = "leomulticloud"
  }
}
