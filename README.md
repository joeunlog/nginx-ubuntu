
---
# Create eks cluster by using ClusterConfig file

## ekscreate.yaml

metadata
- name : spcluster
- region : ap-northeast-2 (SEOUL)

Availability Zone
- ap-northeast-2a
- ap-northeast-2b
- ap-northeast-2c
- ap-northeast-2d

iam *(For controllers running in the kube-system namespace)*
- aws-load-balancer-controller
- ebs-csi-controller-sa
- cluster-autoscaler

managed node group
- instance type : t3.medium
- min size : 2
- desired capacity : 3
- max size : 4
- iam
  - addon policy
    - autoscaler
    - albingress
    - cloudwatch

fargate profile
- name : spfargate
- selector : namespace = spspace

cloudwatch
- cluster logging
  - api
  - audit
  - authenticator
  - controller manager
  - scheduler

## Creating cluster command

```sh
# create cluster
eksctl create cluster -f ekscreate.yaml

# approve iam service account
eksctl create iamserviceaccount -f ekscreate.yaml  --approve

# When an warning occurs
eksctl create iamserviceaccount -f ekscreate.yaml  --approve --override-existing-serviceaccounts
```

## Install add-ons

### aws-load-balancer-contoller

```sh
# apply target group binding custom resource
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"

# add eks-charts repository
helm repo add eks https://aws.github.io/eks-charts

# update local repo
helm repo update

# install aws load balancer contoller
# why image tag v2.1.3 = latest version has bug, not working
helm upgrade -i aws-load-balancer-controller eks/aws-load-balancer-controller \
  --set clusterName=spcluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set image.tag=v2.1.3 \
  -n kube-system

# verify
kubectl get deployment -n kube-system aws-load-balancer-controller
```

### EBS CSI Driver

```sh
# add repo
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver

# repo update
helm repo update

# install aws ebs csi driver
helm upgrade -install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
  --namespace kube-system \
  --set enableVolumeResizing=true \
  --set enableVolumeSnapshot=true \
  --set serviceAccount.controller.create=false \
  --set serviceAccount.controller.name=ebs-csi-controller-sa
```

### Metrics Server

```sh
# Deploy the metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# verify
kubectl get deployment metrics-server -n kube-system
```

### Cluster Autoscaler

```sh
# get cluster-autoscaler-autodiscover.yaml file
curl -o cluster-autoscaler-autodiscover.yaml https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml

```
edit cluster-autoscaler-autodiscover.yaml  
Deployment.spec.template.spec.containers.command
last line  
**\<YOUR CLUSTER NAME> -> spcluster **

```sh
# deploy
kubectl create -f cluster-autoscaler-autodiscover.yaml

# verify
kubectl -n kube-system logs -f deployment.apps/cluster-autoscaler
```

### CloudWatch Container Insights

```sh
# set variables
ClusterName=spcluster
RegionName=ap-northeast-2
FluentBitHttpPort='2020'
FluentBitReadFromHead='Off'
[[ ${FluentBitReadFromHead} = 'On' ]] && FluentBitReadFromTail='Off'|| FluentBitReadFromTail='On'
[[ -z ${FluentBitHttpPort} ]] && FluentBitHttpServer='Off' || FluentBitHttpServer='On'

# deploy (This command is one line.)
curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluent-bit-quickstart.yaml | sed 's/{{cluster_name}}/'${ClusterName}'/;s/{{region_name}}/'${RegionName}'/;s/{{http_server_toggle}}/"'${FluentBitHttpServer}'"/;s/{{http_server_port}}/"'${FluentBitHttpPort}'"/;s/{{read_from_head}}/"'${FluentBitReadFromHead}'"/;s/{{read_from_tail}}/"'${FluentBitReadFromTail}'"/' | kubectl apply -f - 

# verify
kubectl get po -n amazon-cloudwatch
```







---
# Running nginx in ubuntu environment

Dockerfile

```
FROM ubuntu:focal
RUN apt-get update
RUN apt-get install -y nginx
WORKDIR /etc/nginx
CMD ["nginx","-g","daemon off;"]
EXPOSE 80
```