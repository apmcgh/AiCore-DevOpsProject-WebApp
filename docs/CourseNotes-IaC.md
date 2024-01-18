# [CI/CD](../README.md#cicd)

- [IaC, Infrastructure as Code](CourseNotes-IaC.md)
- [WebApp: deployment, access, test and validation](CourseNotes-WebApp.md)
- [Azure Pipeline build and deployment](CourseNotes-Pipeline.md)
- [Cluster monitoring](CourseNotes-Monitoring.md)
- [Key Vault integration](CourseNotes-KeyVault.md)


# IaC

Infrastructure as code is defined in directory `aks-terraform`.

This creates the AKS cluster required to deploy the webapp.


## Azure network resource definition

Terraform module: `aks-terraform/networking-module`

Input variables:
- resource_group_name:   
  Name of the Azure Resource Group in which we define the network for the WebApp

- network_security_group_name:   
  Name of the Azure Network Security Group

- location:   
  Region in which to define resources

- kubectl_ip:   
  Public IP address of the host of kubectl

- vnet_address_space:   
  Address space for the WebApp Virtual Network (VNet).

Output variables:
- vnet_id:   
  ID of the Virtual Network (VNet).

- control_plane_subnet_id:   
  ID of the control plane subnet.

- worker_node_subnet_id:   
  ID of the worker node subnet.

- networking_resource_group_name:   
  Name of the Azure Resource Group for networking resources.

- aks_nsg_id:   
  ID of the Network Security Group (NSG) for AKS.

Defines:
- A Resource Group (RG)
- A Virtual Network (VN) `aks-vnet`, to contain all AKS communications
- A Subnet for the AKS control plane, `control_plane_subnet`
- A Subnet for the AKS worker node, `worker_node_subnet`
- A Network Security Group (NSG) for the AKS network
- Two inbound rules to allow `ssh` and `https` in from my dev host, where I can use kubectl


## AKS cluster definition

Terraform module: `aks-terraform/aks-cluster-module`

Input variables (to define the cluster):
- aks_cluster_name:   Cluster name
- cluster_location:   Region in which to define resources
- dns_prefix
- kubernetes_version
- service_principal_client_id
- service_principal_client_secret

Input variables (output by networking module):
- vnet_id:   
  ID of the Virtual Network (VNet).

- control_plane_subnet_id:   
  ID of the control plane subnet.

- worker_node_subnet_id:   
  ID of the worker node subnet.

- resource_group_name:   
  Name of the Azure Resource Group for networking resources.

Output variables:
- aks_cluster_name:   
  Name of the AKS cluster.

- aks_cluster_id:   
  ID of the AKS cluster.

- aks_kubeconfig:   
  Kubeconfig file for accessing the AKS cluster.

Defines:
- An AKS cluster


## AKS cluster creation

Terraform root module: `aks-terraform`

Input variables:
- client_id:   
  The Client ID for the Azure Service Principal

- client_secret:   
  The Client secret for the Azure Service Principal

The input variables are set by calling `. secrets.sh` to source the relevant `exports`. The `secrets.sh` file id not tracked by `git`, so as to keep secrets secret. The file template below should be populated with the relevant values:
```
# Service principal
export ARM_CLIENT_ID=""         # appId
export ARM_CLIENT_SECRET=""     # password
export ARM_SUBSCRIPTION_ID=""
export ARM_TENANT_ID=""

export TF_VAR_client_id=$ARM_CLIENT_ID
export TF_VAR_client_secret=$ARM_CLIENT_SECRET
```

The first four are used by the `provider` in `main.tf`, the last two are used as input parameters to the aks cluster module.

The subscription id can be got from `az account list`, take note of `Id`, this is the subscription id.

If creating the Service Principal from the az CLI, use
`az ad sp create-for-rbac --name $APP_NAME --role contributor --scopes /subscriptions/$SUBSCRIPTION_ID`,
which provides the client id (appId), client secret (password) and tenant id.

For `APP_NAME`, I used `apmcWebApp`, store the credentials in a safe place, e.g. a password vault or `secrets.sh`.

Output variables:
- resource_group_name
- aks_cluster_name

Defines:
- An AKS cluster, fully configured, with the relevant networking and security resources.

After running `terraform init` in each of the modules, to create the AKS cluster, run:
```
terraform init
terraform plan
terraform apply
```

If needed, delete `~/.kube/config` (if it is almost empty `az` refuses to merge credentials), then run `az aks get-credentials --resource-group $resource_group_name --name $aks_cluster_name` to merge the Azure credentials, taking care to replace the RG and cluster name with the correct values (as output by `terraform apply`).

This command provides `kubectl` with access to monitor and control the cluster - provided the correct Network Security has been set-up.

`kubectl` can be used to check the status of the cluster, e.g.:
```
kubectl config get-contexts
kubectl get nodes -o wide
kubectl get pods,deployment,services -o wide
```