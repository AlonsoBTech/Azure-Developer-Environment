## Azure Developer Environment

## 📋 <a name="table">Table of Contents</a>

1. 🤖 [Introduction](#introduction)
2. ⚙️ [Prerequisites](#prerequisites)
3. 🔋 [What Is Being Created](#what-is-being-created)
4. 🤸 [Quick Guide](#quick-guide)
5. 🔗 [Links](#links)

## <a name="introduction">🤖 Introduction</a>

Creating an Environment in Azure for developers. In this environment we deployed a Linux VM 
installed with Docker and Jenkins allowing developers to test containerized applications as
well as CICD pipelines.


## <a name="prerequisites">⚙️ Prerequisites</a>

Make sure you have the following:

- Azure Account
- Terraform Installed
- IDE of Choice to write Terraform Code

## <a name="what-is-being-created">🔋 What Is Being Created</a>

What we will be using and creating:

- Resource Group
- Virtual Network
- Network Security Group
- Subnet
- Public IP
- Network Interface
- Vitual Machine

## <a name="quick-guide">🤸 Quick Guide</a>

**First create your git repository (name it whatever you like) then clone the git repository**

```bash
git clone https://github.com/AlonsoBTech/Azure-Developer-Environment.git
cd Azure-Developer-Environment
```

**Create your Terraform folder**
```bash
mkdir Terraform
cd Terraform
```

**Create your Terraform providers.tf file**

</details>

<details>
<summary><code>providers.tf</code></summary>

```bash
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.100.0"
    }
  }
}

provider "azurerm" {
  features {}
}
```
</details>

**Create your Terraform main.tf file**

</details>

<details>
<summary><code>main.tf</code></summary>

```bash
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
```

</details>

**Create your customdata.tpl file**

</details>

<details>
<summary><code>customdata.tpl</code></summary>

```bash
#!/bin/bash
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo apt install fontconfig openjdk-17-jre -y
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian/jenkins.io-2023.key
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update
sudo apt-get install jenkins -y
sudo systemctl enable jenkins
sudo systemctl start jenkins
```

</details>

**Create your variables.tf file**

</details>

<details>
<summary><code>variables.tf</code></summary>

```bash
#### VARIABLE VALUES ARE STORED IN "TERRAFORM.TFVARS" ####

variable "rg_location" {
  type = string
}

variable "vnet_dev_cidr" {
  type = string
}

variable "subnet1_dev_cidr" {
  type = string
}

variable "nsgr_my_ip" {
  type = string
}
```

</details>

**Create your .gitignore file**

</details>

<details>
<summary><code>.gitignore</code></summary>

```bash
.terraform
.terreform.lock.hcl
terraform.tfvars
*.tfstate
*.tfstate.*
```

</details>

## <a name="links">🔗 Links</a>

- [Terraform Azure Provider Registry](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

