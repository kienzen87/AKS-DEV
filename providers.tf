provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

terraform {
  backend "azurerm" {
    storage_account_name = "fraportstorage"
    container_name       = "fraportcontainer"
    key                  = "fraportdev.terraform.tfstate"
    access_key            = "Mnd00QKs0OA5chj6bIJKCwXsndvFr9KvBuheeTOYEeialHFB+7RhTM/RzI1Ih6bd1dgMjNX4EgAh+AStoBiQHQ=="
  }
}

terraform {
  required_version = ">=1.3"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.51.0, < 4.0"
    }
    curl = {
      source  = "anschoewe/curl"
      version = "1.0.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.3.2"
    }
  }
}
