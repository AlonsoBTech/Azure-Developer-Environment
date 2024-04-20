resource "azurerm_resource_group" "rg_dev_test" {
  name     = "rg_dev_test"
  location = var.rg_location

  tags = {
    environment = "Dev"
  }
}

resource "azurerm_virtual_network" "vnet_dev" {
  name                = "vnet_dev"
  location            = azurerm_resource_group.rg_dev_test.location
  resource_group_name = azurerm_resource_group.rg_dev_test.name
  address_space       = [var.vnet_dev_cidr]
}

resource "azurerm_subnet" "subnet1_dev" {
  name                 = "dev_subnet1"
  resource_group_name  = azurerm_resource_group.rg_dev_test.name
  virtual_network_name = azurerm_virtual_network.vnet_dev.name
  address_prefixes     = [var.subnet1_dev_cidr]
}

resource "azurerm_network_security_group" "nsg_dev" {
  name                = "nsg_dev"
  location            = azurerm_resource_group.rg_dev_test.location
  resource_group_name = azurerm_resource_group.rg_dev_test.name
}

resource "azurerm_network_security_rule" "nsgr_dev" {
  name                        = "nsgr_dev"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = var.nsgr_my_ip
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg_dev_test.name
  network_security_group_name = azurerm_network_security_group.nsg_dev.name
}

resource "azurerm_subnet_network_security_group_association" "nsg_asso" {
  subnet_id                 = azurerm_subnet.subnet1_dev.id
  network_security_group_id = azurerm_network_security_group.nsg_dev.id
}

resource "azurerm_public_ip" "pip_dev" {
  name                    = "pip_dev"
  location                = azurerm_resource_group.rg_dev_test.location
  resource_group_name     = azurerm_resource_group.rg_dev_test.name
  allocation_method       = "Dynamic"
  idle_timeout_in_minutes = 30

  tags = {
    environment = "Dev"
  }
}

resource "azurerm_network_interface" "nic_dev" {
  name                = "nic_dev"
  location            = azurerm_resource_group.rg_dev_test.location
  resource_group_name = azurerm_resource_group.rg_dev_test.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet1_dev.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip_dev.id
  }
}

resource "azurerm_linux_virtual_machine" "vm_dev_linux" {
  name                = "vm1linux"
  resource_group_name = azurerm_resource_group.rg_dev_test.name
  location            = azurerm_resource_group.rg_dev_test.location
  size                = "Standard_B1s"
  admin_username      = "adminuser"
  network_interface_ids = [azurerm_network_interface.nic_dev.id,]
  custom_data = filebase64("customdata.tpl")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/devkey.pub")
  }

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
}

data "azurerm_public_ip" "pip_data" {
    name = azurerm_public_ip.pip_dev.name 
    resource_group_name = azurerm_resource_group.rg_dev_test.name 
}

output "jenkins_server_dns" {
    value = "${azurerm_linux_virtual_machine.vm_dev_linux.name}: ${data.azurerm_public_ip.pip_data.ip_address}:8080"
}