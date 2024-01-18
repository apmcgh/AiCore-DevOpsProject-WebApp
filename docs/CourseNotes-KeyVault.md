# [CI/CD](../README.md#cicd)

- [IaC, Infrastructure as Code](CourseNotes-IaC.md)
- [WebApp: deployment, access, test and validation](CourseNotes-WebApp.md)
- [Azure Pipeline build and deployment](CourseNotes-Pipeline.md)
- [Cluster monitoring](CourseNotes-Monitoring.md)
- [Key Vault integration](CourseNotes-KeyVault.md)


# Azure Key Vault integration

## History and what did not work

The initial cluster was created with a service principal.

In order to integrate the key vault without requiring the web app to supply a client Id, we need to work with managed identities.

However the container insights having been enabled prior seemed to interfere with the identification of the relevant identity and led to application errors when run in the cluster. These errors, "too many identities", could be worked around by specifying the client ID of the relevant identity, but that defeats the purpose  as the goal was to make access to secrets seamless.


## Solution to Key Vault integration

### Infrastructure

First destroy the cluster to start from scratch again.

Change the cluster definition (terraform file) to set-up the system managed identity, instead of relying on the service principal:

- remove:
  ```
  service_principal {
    client_id     = var.service_principal_client_id
    client_secret = var.service_principal_client_secret
  }
  ```

- add:
  ```
  identity {
    type = "SystemAssigned"
  }
  ```

Use `terraform init` in all relevant directories, `terraform apply` to re-create the cluster.

Using the Azure portal, create a key vault, assign the "Key VAult Administrator" role to the Azure account user. This allows the user to interact with thee key vault, thereby allowing them to create,change or delete secrets.

Using the command line, find out the identity that needs access to the secrets for seamless operation. It seems that the cluster's identity is the wrong choice, instead we need to find the agent pool identity of the cluster.

The agent pool Id is the client Id of the identityProfile of the cluster:

`az aks show --resource-group $RG --name $CLUSTER_NAME --query identityProfile`

Assign the right role to this Id:

`az role assignment create --assignee $clientIdOfIdentityProfile --role "Key Vault Secrets Officer" --scope /subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.KeyVault/vaults/$KEY_VAULT_NAME`


### Manage secrets

Create four secrets to store the database server, DB name, user and password, so that the web app can be written without their knowledge. All the web app now needs to know is that Azure provides a mechanism to make the secrets available on demand so long as the correct permissions are assigned.


### Web App

To access the secrets from the key vault, the app must authenticate. This is done by a single call which works for both local operation and in the cluster. The call automatically determines which identity, if one is available, to use to access the credentials. If these credentials have the correct role(s), then the application can access the key vault and read the secrets.

- load the relevant libraries:   
  ```
  from azure.keyvault.secrets import SecretClient
  from azure.identity import DefaultAzureCredential
  ```

- as an additional step I abstracted the key vault name to an environment variable, set in the deployment manifest, this is used to determine the key vault access URL:   
  ```
  KeyVaultName = os.environ["KEY_VAULT_NAME"]
  KVUri = f"https://{KeyVaultName}.vault.azure.net"
  ```

- set-up the  credentials:   
  ```
  Credential = DefaultAzureCredential()
  ```

- and access the key vault:   
  ```
  KeyVault = SecretClient(vault_url=KVUri, credential=Credential)
  ```

- then read the secrets:
  ```
  server = KeyVault.get_secret("Webapp-DB-Server-Name").value
  database = KeyVault.get_secret("Webapp-DB-Server-Database").value
  username = KeyVault.get_secret("Webapp-DB-Server-Username").value
  password = KeyVault.get_secret("Webapp-DB-Server-UserPassword").value
  ```

These secrets are required to access the database. Abstracting them away means:
- developers do not need to know access codes to operational databases, improving confidentiality, possibly enabling compliance with certain regulations or laws such as GDPR
- a change of access credentials does not require a change of application code or a full deployment
- it makes it easy to set-up various environments in which to test different parts of the app or different features, and also makes it easier to plan operational database migrations


### Container Insights

While the initial approach failed to deliver seamless access to secrets with container insights enabled, this second approach was tested with container insights enabled (after creation of the cluster with system managed identity).

I tested multiple node upgrades to make sure both insights and access to secrets persisted through cluster and pod restarts.

However there is still room for improving the automation of the provision of infrastructure. I feel more could be done to automate the provision of the key vault, correct role assignments and enabling container insights. As this beyond the scope of this project, this is it.
