# AiCore Project Log

Author: Alain Culos   
Date created: 2024-01-03


# Milestones 1 & 2 - Fork repo and run App

Clone the "starter" repo & set-up my local environment:
```
git clone git@github.com:apmcgh/AiCore-DevOpsProject-WebApp.git
cd AiCore-DevOpsProject-WebApp
conda create -n AiCore-DevOpsProject-WebApp
conda activate AiCore-DevOpsProject-WebApp
cat requirements.txt 
conda install --file requirements.txt
snap code run .
```

Note: the dev branch used environment variables, so I created a test azure DB.
I got the connection working, but hit a 'bug' as the DB was empty.

I had to enable SQL authentication for the DB server (azure portal).

This, however, was unnecessary at this stage as the main branch used hard coded DB credentials.

Azure Portal DB: Query editor
```
CREATE USER [TestUser] WITH PASSWORD = 'tP1243tP';
EXEC sp_addrolemember 'db_datareader', 'TestUser';
EXEC sp_addrolemember 'db_datawriter', 'TestUser';
```

When making the change to add a delivery date, I realised that the change could not work as the DB had not been modified to add the extra field. A complete change would require some schema migration.

When reverting the change, I learnt that git revert must target the first commit of the unwanted change rather than the previous commit. Also if the git status is dirty while "reverting", the git revert will include unwanted changes.


# Milestone 3 - Containerisation

Create Dockerfile 
```
git branch feature/containerise-application
git co feature/containerise-application 
git add Dockerfile 
git commit -m 'adds Dockerfile'
git push --set-upstream origin feature/containerise-application
docker build -t aicore-devopsproject-webapp .

docker run -p 5000:5000 aicore-devopsproject-webapp
docker tag aicore-devopsproject-webapp:latest asoundmove/aicore-devopsproject-webapp:latest
docker push  asoundmove/aicore-devopsproject-webapp:latest
```

I needed to create a 'repository' (using the name of the image I wanted to store my build under) in docker hub, before I could push it.

I learnt that the Dockerfile COPY with a source directory copies only the contents of that directory rather than the directory itself (and contents). So in order to avoid copying unwanted files, I had to copy files and directories as separate commands.

Kept track of everything in a feature branch, then merged to main.


# Milestones 4, 5 & 6 - IaC, terraform

## networking module

I adapted the networking module created in an earlier lesson.   
Added a `.gitignore` before issuing `terraform init` in the module directory.   
Keeping track of changes in branch `feature/terraform`.   

Added a spell check extension to VS Code.


## AKS cluster module

I adapted the cluster module created in an earlier lesson.   


## Create a service principal

`az account list`, take note of `Id`, this is the subscription id to use in the next command.

`az ad sp create-for-rbac --name $APP_NAME --role contributor --scopes /subscriptions/$SUBSCRIPTION_ID`

For `APP_NAME`, I used `apmcWebApp`, store the credentials in a safe place, e.g. a password vault.


## Create cluster

Adapt `main.tf` & co. from previous lesson, using environment variables to pass secrets.

Then, do:
```
terraform init
terraform plan
terraform apply
# If needed:
#rm ~/.kube/config
az aks get-credentials --resource-group aks-nw-rg --name terraform-aks-cluster-webapp
```


# Milestone 7 - Deploy webapp on AKS

I adapted the `nginx` sample deployment from a previous lesson.


# Milestone 8 - Azure DevOps project

In [My Azure DevOps account](https://dev.azure.com/apmcazure/), create project `AiCore--DevOps-Course`.

Create a new pipeline, select GitHub, select the relevant AiCore webapp project repo, use the starter pipeline template. Save the pipeline, creating a `feature/azure-pipeline` branch.

## Docker Hub

My account ⇒ Security ⇒ New Access Token ⇒ `aicore-webapp-project-pipeline`, RWD ⇒ Generate 
Copy token and save in personal key vault.

## Azure DevOps

Project settings ⇒ Service connections ⇒ New service connection ⇒ Docker registry ⇒ Next ⇒ Docker Hub ⇒   
Docker ID: docker hub username (not email address)   
Docker password: the access token created above   
Service connection name: Something descriptive, e.g. apmc-docker   
Grant access to all pipelines: Yes
⇒ Verify and Save

I hit a few "misreading" issues:   
- Azure DevOps settings:   
  Azure DevOps portal ⇒ Account ⇒ Organisation settings ⇒ Billing:   
  - Set-up billing with the relevant subscription.
  - Change MS Hosted CI/CD to 2
- Pipeline yaml:   
  - the Docker Hub repo includes the username
  - the build inputs should include tags

After this, I changed the `orders,html` page title to trigger the build, then manually triggered the rollout: `kubectl rollout restart deployment`, refreshed the browser at `${PUBLIC_IP}`, and it showed the updated title 😁

## Kubernetes

Project settings ⇒ Service connections ⇒ New service connection ⇒ Kubernetes
Select Azure, subscription, cluster and namespace.
Give it a name, tick admin credentials and apply to all pipelines.


# Milestone 9 - Monitoring

## Enable container insights

Azure portal ⇒ ... ⇒ AKS cluster ⇒ Monitoring ⇒ Configure ⇒ Configure (+wait)

Cannot see any event recorded in the KubeEvents table, so:
- I destroyed my cluster
- Added a Log Analytics Contributor role to my SP
- Re-created the cluster
- Merged credentials on my dev host
- Re-enabled insights & diagnostics
- Re-established the DevOps pipeline service connection to the cluster
- Re-deployed the webapp (using the pipeline)

Now I can see events in the KubeEvents table, but I still cannot see my pipeline deployment/rollout events!!!

- I destroyed my cluster
- Added a Monitoring Metrics Publisher role to my SP
- Re-created the cluster
- Merged credentials on my dev host
- Re-enabled insights & diagnostics
- Re-established the DevOps pipeline service connection to the cluster
- Re-deployed the webapp (using the pipeline)

I still cannot see my pipeline deployment/rollout events!!!

The Monitoring Metrics Publisher role does not seem to have had any impact.

In fact, maybe the rollout events belong to a different table?

# Milstone 10 - Key Vault

## Enable Managed Identity for AKS to access the Key Vault

`az aks update --resource-group aks-nw-rg --name terraform-aks-cluster-webapp --enable-managed-identity`

`az aks nodepool upgrade --resource-group aks-nw-rg --cluster-name terraform-aks-cluster-webapp --name default --node-image-only`

This last command triggers a cluster restart. So I tested the webapp availability after the restart completed. Note that the service's LB external IP address remained the same.

Check the identity created:

`az aks show --resource-group aks-nw-rg --name terraform-aks-cluster-webapp --query identity`

Assign it a role:

`az role assignment create --assignee <principal-id> --role "Key Vault Secrets Officer" --scope /subscriptions/<subscription-id>/resourceGroups/<resource-group-name>/providers/Microsoft.KeyVault/vaults/<key-vault-name>`

## Update the app to use managed secrets

