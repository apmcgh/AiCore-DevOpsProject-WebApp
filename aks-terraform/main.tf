terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  features {
    # Relies on `az login`
  }
}

module "networking" {
  source = "./networking-module"

  # Input variables for the networking module
  resource_group_name         = "aks-nw-rg"
  network_security_group_name = "aks-nw-sg"
  location                    = "UK South"
  vnet_address_space          = ["10.0.0.0/16"]
}

module "aks_cluster" {
  source = "./aks-cluster-module"

  # Input variables for the AKS cluster module
  aks_cluster_name           = "terraform-aks-cluster-webapp"
  cluster_location           = "UK South"
  dns_prefix                 = "aks-webapp"
  kubernetes_version         = "1.28.3"

  # Input variables referencing outputs from the networking module
  resource_group_name         = module.networking.networking_resource_group_name
  vnet_id                     = module.networking.vnet_id
  control_plane_subnet_id     = module.networking.control_plane_subnet_id
  worker_node_subnet_id       = module.networking.worker_node_subnet_id

  depends_on = [ module.networking ]
}