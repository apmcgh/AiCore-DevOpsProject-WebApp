# [CI/CD](../README.md#cicd)

- [IaC, Infrastructure as Code](CourseNotes-IaC.md)
- [WebApp: deployment, access, test and validation](CourseNotes-WebApp.md)
- [Azure Pipeline build and deployment](CourseNotes-Pipeline.md)
- [Cluster monitoring](CourseNotes-Monitoring.md)


# Azure Pipeline build and deployment

## Lessons learnt:

- by default azure pipelines trigger on Pull Request and merge.
  When set-up to trigger on a PR, a pipeline acts as a validity check
  for the PR.
- the setting to change the above behaviour 'sticks' when removed,
  i.e. when setting `pr: none`, it disables PR triggers,but removing
  that line does not reinstate the trigger. It needs to be reinstated
  explicitly with something like:   
  ```
  pr:
  - '*'
  ```
- it is possible to bypass the PR validity check by being quick at clicking
  on 'merge' immediately after having created the pull request and before the
  pipeline trigger has been initiated. The unfortunate consequence is that this
  triggers two concurrent runs of the pipeline, which can have unintended
  consequences. So, I suggest there should be two good practices to adhere to:
  1. not rush into clicking on 'merge', wait 10 seconds or so,
  1. use different pipelines for PR checks and commit/merge triggers.
- `kubectl apply` does not deploy a new image if it has the same tag, in this
  case we need to use `kubectl rollout restart deployment`.

## Testing:

To make sure the correct docker image got deployed, I changed the title of the
main page of the webapp on every update I wanted this checked.

Monitoring the pod deployment live enabled me to catch and understand the double
rollout when the PR and merge triggers were initiated in quick succession.

## Local monitoring:

My monitoring scripts are as follows:

In my `.bashrc`, I have a very optional pretty horizontal rule function:
```
function hr() 
{ 
    printf "\e[4;49;95m%-*s\e[0m\n" $(tput cols) "$@"
}
export -f hr
```

In my `~/bin` directory (on my `$PATH`), I have the following two scripts:

`watch-kube-status.sh`:
```
#!/bin/bash

watch --color -d -n 1 kube-status.sh
```

`kube-status.sh`:
```
#!/bin/bash

hr "minikube status"
minikube status

hr "contexts"
kubectl config get-contexts

current_context="$(kubectl config current-context)"

if [ "${current_context}" != "" ]
then
  hr "${current_context}  nodes:"
  kubectl get nodes -o wide
  hr "${current_context}  pods,deployment,services:"
  kubectl get pods,deployment,services -o wide
fi
```

Running `watch-kube-status.sh` allows near real-time monitoring of the
status of the AKS cluster in the terminal.