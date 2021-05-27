
---
# Create eks cluster by using ClusterConfig file

> github **setup** directory

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

> [Refer to the docs](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html)

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

> **Could not find webhook error while using load balancer**

```sh
# Since we don't use webhooks, we can solve it by deleting webhook configuration.
kubectl delete validatingwebhookconfiguration aws-load-balancer-webhook
```

### EBS CSI Driver

> [Refer to the docs](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html)

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

> [Refer to the docs](https://docs.amazonaws.cn/en_us/eks/latest/userguide/metrics-server.html)

```sh
# Deploy the metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# verify
kubectl get deployment metrics-server -n kube-system
```

### Cluster Autoscaler

> [Refer to the docs](https://docs.aws.amazon.com/eks/latest/userguide/cluster-autoscaler.html)

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

> [Refer to the docs](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-EKS-quickstart.html)

```sh
# set variables
ClusterName=spcluster
RegionName=ap-northeast-2
FluentBitHttpPort='2020'
FluentBitReadFromHead='Off'
[[ ${FluentBitReadFromHead} = 'On' ]] && FluentBitReadFromTail='Off'|| FluentBitReadFromTail='On'
[[ -z ${FluentBitHttpPort} ]] && FluentBitHttpServer='Off' || FluentBitHttpServer='On'

# deploy
curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluent-bit-quickstart.yaml | sed 's/{{cluster_name}}/'${ClusterName}'/;s/{{region_name}}/'${RegionName}'/;s/{{http_server_toggle}}/"'${FluentBitHttpServer}'"/;s/{{http_server_port}}/"'${FluentBitHttpPort}'"/;s/{{read_from_head}}/"'${FluentBitReadFromHead}'"/;s/{{read_from_tail}}/"'${FluentBitReadFromTail}'"/' | kubectl apply -f - 

# verify
kubectl get po -n amazon-cloudwatch
```







---
# Running nginx in ubuntu environment

> github **root** directory

## Link github and dockerhub

*If you don't want to connect to an account, skip this step*  
*You can connect to the repository only by 'configure automated builds' menu*

1. Log in to dockerhub  
2. Go to the account settings screen as shown in the figure below.

![hi](/img/dockerhub_accountsetting.png)

3. Select github connect from the 'linked account' menu
4. If connected properly, the following screen will be displayed.

![hi](/img/dockerhub_connected.png)

## Create dockerhub repository and set automated build

1. Create repository
2. Go to the build menu of the created repository
3. Select the connected github and select organizaion, repository   
   > *If you skipped the account linking step, select 'configure automated builds' menu*

![hi](/img/autobuild_setting01.png)

4. Complete the detailed settings created below and save.

![hi](/img/autobuild_setting02.png)

5. After checking the status, if additional build is needed, press the trigger.

![hi](/img/autobuild_setting03.png)

6. Check if the build was successful.

```sh
docker run -itd -p 8080:80 [username]/[repository name]
```

## Create Dockerfile

```
FROM ubuntu:focal
RUN apt-get update
RUN apt-get install -y nginx
WORKDIR /etc/nginx
CMD ["nginx","-g","daemon off;"]
EXPOSE 80
```

