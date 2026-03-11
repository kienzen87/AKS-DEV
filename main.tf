data "azurerm_client_config" "current" {}

# Address Space chosen randomly
resource "azurerm_virtual_network" "test" {
  address_space       = ["10.52.0.0/16"]
  name                = "test-vn"
  resource_group_name = "company"
  location            = "germanywestcentral"
}

# random subnet
resource "azurerm_subnet" "test" {
  address_prefixes                               = ["10.52.0.0/24"]
  name                                           = "test-sn"
  resource_group_name                            = "company"
  virtual_network_name                           = azurerm_virtual_network.test.name
  enforce_private_link_endpoint_network_policies = true
}

# random address space for AKS
resource "azurerm_subnet" "aks" {
  address_prefixes                               = ["10.52.1.0/24"]
  name                                           = "aks-sn"
  resource_group_name                            = "company"
  virtual_network_name                           = azurerm_virtual_network.test.name
  enforce_private_link_endpoint_network_policies = true
}

# Azure basstion requires a subnet with a hardcoded name
resource "azurerm_subnet" "AzureBastionSubnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = "company"
  virtual_network_name = azurerm_virtual_network.test.name
  address_prefixes     = ["10.52.2.0/24"]
}

# Azure Bastion needs a public IP
resource "azurerm_public_ip" "pip" {
  name                = "public-ip"
  location            = "germanywestcentral"
  resource_group_name = "company"
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion" {
  name                = "bastion"
  location            = "germanywestcentral"
  resource_group_name = "company"

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.AzureBastionSubnet.id
    public_ip_address_id = azurerm_public_ip.pip.id
  }  
  }

resource "azurerm_user_assigned_identity" "test" {
  location            = "germanywestcentral"
  name                = "aks-identity"
  resource_group_name = "company"
}

resource "azurerm_role_assignment" "keyvaultreader" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Reader"
  principal_id         = azurerm_user_assigned_identity.test.principal_id
}

resource "azurerm_role_assignment" "dnszonecontributor" {
  scope                = azurerm_private_dns_zone.aks.id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.test.principal_id
}


module "aks" {
  source  = "Azure/aks/azurerm"
  version = "9.1.0"
  resource_group_name = "company"
  cluster_log_analytics_workspace_name = "companydevlawos"
  prefix = "fradev"
  role_based_access_control_enabled = "true"
  location = "germanywestcentral"
  key_vault_secrets_provider_enabled = "true"
  oidc_issuer_enabled = "true"
  rbac_aad = "true"
  rbac_aad_managed = "true"
  rbac_aad_admin_group_object_ids = ["48258e51-2df9-4926-a717-d9038a9c72c6"]
  rbac_aad_azure_rbac_enabled = "true"
  workload_identity_enabled = "true"
  identity_ids                         = [azurerm_user_assigned_identity.test.id]
  identity_type                        = "UserAssigned"
  private_dns_zone_id        = azurerm_private_dns_zone.aks.id
  private_cluster_enabled    = true
  vnet_subnet_id = azurerm_subnet.aks.id
  temporary_name_for_rotation = "temppool"
  network_plugin   = "azure"
  network_policy   = "azure"
  load_balancer_sku = "standard"
}

resource "azurerm_private_dns_zone" "aks" {
  name                = "privatelink.germanywestcentral.azmk8s.io"
  resource_group_name = "company"
}

resource "azurerm_private_dns_zone_virtual_network_link" "aks" {
  name                  = "aks"
  resource_group_name   = "company"
  private_dns_zone_name = azurerm_private_dns_zone.aks.name
  virtual_network_id    = azurerm_virtual_network.test.id
}

resource "random_string" "key_vault_prefix" {
  length  = 7
  numeric = false
  special = false
  upper   = false
}


resource "azurerm_container_registry" "acr" {
  name                = "349875498hrijwe"
  resource_group_name = "company"
  location            = "germanywestcentral"
  sku                 = "Premium"
}

# Role Assignments to AKS Kubelet Identity to pull images from the ACR.
resource "azurerm_role_assignment" "role_assignment_aks_acr" {
  scope                            = azurerm_container_registry.acr.id
  role_definition_name             = "AcrPull"
  principal_id                     = module.aks.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_key_vault" "kv" {
  location                    = "germanywestcentral"
  name                        = "rjlk4325432655-kv"
  resource_group_name         = "company"
  sku_name                    = "premium"
  tenant_id                   = var.azure_tenant_id
  enabled_for_disk_encryption = true
  purge_protection_enabled    = false
  enable_rbac_authorization   = true

# Allow public access for ease of work
  network_acls {
    bypass         = "AzureServices"
    default_action = "Allow"
  }
  
}

# example secret to be mounted in a test application
resource "azurerm_key_vault_secret" "test-secret" {
  name         = "arbitrarySecret"
  value        = "testsecretvalue"
  key_vault_id = azurerm_key_vault.kv.id
   depends_on = [
azurerm_role_assignment.terraformsp-keyvaultadmin
 ]
}

resource "azurerm_private_dns_zone" "kv" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = "company"
}

resource "azurerm_private_dns_zone_virtual_network_link" "akv" {
  name                  = "test"
  resource_group_name   = "company"
  private_dns_zone_name = azurerm_private_dns_zone.kv.name
  virtual_network_id    = azurerm_virtual_network.test.id
}

resource "azurerm_private_endpoint" "kv_private_endpoint" {
  name                = lower("${azurerm_key_vault.kv.name}-ep")
  location            = "germanywestcentral"
  resource_group_name = "company"
  subnet_id           = azurerm_subnet.test.id
 
  private_dns_zone_group {
    name                 = "privatelink.vaultcore.azure.net"
    private_dns_zone_ids = [azurerm_private_dns_zone.kv.id]
  }
 
  private_service_connection {
    name                           = lower("${azurerm_key_vault.kv.name}-psc")
    private_connection_resource_id = azurerm_key_vault.kv.id
    is_manual_connection           = false
    subresource_names              = ["Vault"]
  }
}

resource "azurerm_network_interface" "vm" {
  name                = "jumpserver-nic"
  location            = "germanywestcentral"
  resource_group_name = "company"

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = azurerm_subnet.test.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "jumpserver" {
  name                = "Jumpserver-vm"
  resource_group_name = "company"
  location            = "germanywestcentral"
  size                = "Standard_F2"
  admin_username      = "adminuser"
  admin_password      = "Password1234!"
  network_interface_ids = [
    azurerm_network_interface.vm.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "self-hsoted-agent" {
    name                 = "Jumpserver-vm"
    virtual_machine_id   = azurerm_windows_virtual_machine.jumpserver.id
    publisher            = "Microsoft.Compute"
    type                 = "CustomScriptExtension"
    type_handler_version = "1.9"

    protected_settings = <<SETTINGS
    {
    "commandToExecute": "powershell -command \"[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${base64encode(data.template_file.ADDS.rendered)}')) | Out-File -filepath ADDS.ps1\" && powershell -ExecutionPolicy Unrestricted -File ADDS.ps1 -URL ${data.template_file.ADDS.vars.URL} -PAT ${data.template_file.ADDS.vars.PAT} -POOL ${data.template_file.ADDS.vars.POOL} -AGENT ${data.template_file.ADDS.vars.AGENT}"
    }
    SETTINGS

  
}

#Variable input for the ADDS.ps1 script
data "template_file" "ADDS" {
    # for_each    = local.scripts_to_execute
    template    = "${file("windows-agent-install.ps1")}"
    vars = {
        URL     =   "https://dev.azure.com/OS-company-Dev/"   
        PAT     =   "26swzs7bmqaw2ae26vy5ouyc7nedqpn2ix7rnltsscknqy7dd3pa"
        POOL    =   "Default"   
        AGENT   =   "Jumpserver-vm"
        }
}

#Add RBAC to Terraform service principal to access keyVault and AKS
resource "azurerm_role_assignment" "terraformsp-keyvaultreader" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Reader"
  principal_id         = "f5dfac11-1783-43fb-bede-cfa43f90ed6b"
}

resource "azurerm_role_assignment" "terraformsp-keyvaultadmin" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = "f5dfac11-1783-43fb-bede-cfa43f90ed6b"
}

resource "azurerm_role_assignment" "aks-namespaceuser" {
  scope                = module.aks.aks_id
  role_definition_name = "Azure Kubernetes Service Namespace User"
  principal_id         = "f5dfac11-1783-43fb-bede-cfa43f90ed6b"
}

resource "azurerm_role_assignment" "aks-contributor" {
  scope                = module.aks.aks_id
  role_definition_name = "Azure Kubernetes Service Contributor Role"
  principal_id         = "f5dfac11-1783-43fb-bede-cfa43f90ed6b"
}

resource "azurerm_role_assignment" "aks-rbac_cluster_admin" {
  scope                = module.aks.aks_id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = "f5dfac11-1783-43fb-bede-cfa43f90ed6b"
}



# We connect a user assigned identity (workload ID) from EntraID with a service account withing AKS

resource "azurerm_user_assigned_identity" "app5" {
  location            = "germanywestcentral"
  name                = "id-app5"
  resource_group_name = "company"
}

resource "azurerm_federated_identity_credential" "app5" {
  name                = "id-app5"
  resource_group_name = "company"
  audience            = ["api://AzureADTokenExchange"]
  issuer              = module.aks.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.app5.id
  subject             = "system:serviceaccount:app5:app5-workloadidapp5"
}

resource "azurerm_role_assignment" "app5-keyvaultreader" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Reader"
  principal_id         = azurerm_user_assigned_identity.app5.principal_id
}

resource "azurerm_role_assignment" "keyvaultsecretsuser" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app5.principal_id
}
