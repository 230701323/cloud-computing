provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "gitea_rg" {
  name     = "gitea-rg"
  location = "East US"
}

resource "azurerm_virtual_network" "gitea_vnet" {
  name                = "gitea-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.gitea_rg.location
  resource_group_name = azurerm_resource_group.gitea_rg.name
}

resource "azurerm_subnet" "gitea_subnet" {
  name                 = "gitea-subnet"
  resource_group_name  = azurerm_resource_group.gitea_rg.name
  virtual_network_name = azurerm_virtual_network.gitea_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "gitea_nsg" {
  name                = "gitea-nsg"
  location            = azurerm_resource_group.gitea_rg.location
  resource_group_name = azurerm_resource_group.gitea_rg.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Gitea"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "gitea_ip" {
  name                = "gitea-ip"
  location            = azurerm_resource_group.gitea_rg.location
  resource_group_name = azurerm_resource_group.gitea_rg.name
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "gitea_nic" {
  name                = "gitea-nic"
  location            = azurerm_resource_group.gitea_rg.location
  resource_group_name = azurerm_resource_group.gitea_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.gitea_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.gitea_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  network_interface_id      = azurerm_network_interface.gitea_nic.id
  network_security_group_id = azurerm_network_security_group.gitea_nsg.id
}

resource "azurerm_linux_virtual_machine" "gitea_vm" {
  name                = "gitea-vm"
  resource_group_name = azurerm_resource_group.gitea_rg.name
  location            = azurerm_resource_group.gitea_rg.location
  size                = "Standard_B1s"
  admin_username      = "azureuser"

  network_interface_ids = [
    azurerm_network_interface.gitea_nic.id,
  ]

  admin_password                  = "YourPassword123!"
  disable_password_authentication = false

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(file("install_gitea.sh"))
}