resource "azurerm_resource_group" "secondary" {
  name     = "leomulticloud-rg"
  location = var.azure_region
}

resource "azurerm_virtual_network" "secondary" {
  name                = "leomulticloud-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.secondary.location
  resource_group_name = azurerm_resource_group.secondary.name
}

resource "azurerm_subnet" "secondary" {
  name                 = "leomulticloud-subnet"
  resource_group_name  = azurerm_resource_group.secondary.name
  virtual_network_name = azurerm_virtual_network.secondary.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "secondary" {
  name                = "leomulticloud-pip"
  location            = azurerm_resource_group.secondary.location
  resource_group_name = azurerm_resource_group.secondary.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Project = "leomulticloud"
    Role    = "secondary"
  }
}

resource "azurerm_network_security_group" "secondary" {
  name                = "leomulticloud-nsg"
  location            = azurerm_resource_group.secondary.location
  resource_group_name = azurerm_resource_group.secondary.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "secondary" {
  name                = "leomulticloud-nic"
  location            = azurerm_resource_group.secondary.location
  resource_group_name = azurerm_resource_group.secondary.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.secondary.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.secondary.id
  }
}

resource "azurerm_network_interface_security_group_association" "secondary" {
  network_interface_id      = azurerm_network_interface.secondary.id
  network_security_group_id = azurerm_network_security_group.secondary.id
}

resource "azurerm_linux_virtual_machine" "secondary" {
  name                = "leomulticloud-secondary"
  resource_group_name = azurerm_resource_group.secondary.name
  location            = azurerm_resource_group.secondary.location
  size                = var.azure_vm_size
  admin_username      = "azureuser"

  network_interface_ids = [azurerm_network_interface.secondary.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # Azure requires cloud-init to be base64-encoded
  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    cloud_provider  = "Azure"
    app_user        = "azureuser"
    app_port        = var.app_port
    weather_api_key = var.weather_api_key
    repo_url        = var.repo_url
    deploy_commit   = var.deploy_commit
  }))

  tags = {
    Project = "leomulticloud"
    Role    = "secondary"
  }
}
