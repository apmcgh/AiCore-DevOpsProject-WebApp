# [CI/CD](../README.md#cicd)

- [IaC, Infrastructure as Code](CourseNotes-IaC.md)
- [WebApp: deployment, access, test and validation](CourseNotes-WebApp.md)
- [Azure Pipeline build and deployment](CourseNotes-Pipeline.md)
- [Cluster monitoring](CourseNotes-Monitoring.md)
- [Key Vault integration](CourseNotes-KeyVault.md)


# WebApp deployment on AKS

Directory `k8s-webapp` contains the `webapp` manifest.   
This kubernetes declarative configuration defines:
- a replica set with two instances of the containerised webapp.   
  The replica set works because webapp is stateless.   
  Using two instances means that if one were to fail, the other can take the load while the failed one is automatically restarted by the control plane. This offers operation without downtime so long as both
  instances do not fail at the same time.
- a service definition to enable network services within the cluster.   
  The service provides a load balanced access point to all webapp pods.

The rolling deployment strategy, with for parameter to replace one pod at a time, ensures continuous operation when the webapp is updated for a new version - so long as the new version works as expected.

Use `kubectl apply -f application-manifest.yaml` to start the webapp (replica set deployment and service).

`kubectl port-forward service/webapp-service 8080:80` forwards port 80 of the cluster to local port 8080, this allows testing with e.g. `firefox localhost:8080`.


# WebApp access without port-forwarding

First attempt: To enable access to the cluster from a specific LAN behind a NAT, we need to allow access inbound to service port 80 from the public IP address of the NAT, and provide a public IP address for the cluster, this is done by changing the service manifest from ClusterIP to LoadBalancer. We can then find out the external IP address of the LB with `kubectl get svc webapp-service`, and access the service by browsing `http://$EXTERNAL_IP_ADDRESS`.

Having just tried the above, what happens is that the LoadBalancer created by Azure in response to the kubectl service request opens inbound to the whole world by default, bypassing the NSG. The restriction must be defined in the service definition using the keyword `loadBalancerSourceRanges` and supplying a list of CIDRs. This effectively restricts access to the LB.

A more complex answer would be required if we needed to secure the access with SSL/TLS/https. We may need to configure an Ingress controller.

For access to external users, we simply need to (---relax the inbound rule on port 80---) remove the `loadBalancerSourceRanges` to enable all source IP addresses.

Ref. [Support for setting Network Security Group for AKS cluster/nodepool](https://github.com/hashicorp/terraform-provider-azurerm/issues/10233)


# WebApp deployment testing and validation

Access tests:
- access to the WebApp through port forwarding (ClusterIP)
- access to the WebApp to external IP (LB)
- access timeout for device not on LAN

Functional tests:
- check all pages display
- add an order
- check the new order is listed