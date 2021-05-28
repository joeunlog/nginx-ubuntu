
---
<p align="center">
<h1>Wordpress - MySQL</h1>  
</p>


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
$ eksctl create cluster -f ekscreate.yaml

# approve iam service account
$ eksctl create iamserviceaccount -f ekscreate.yaml  --approve

# When an warning occurs
$ eksctl create iamserviceaccount -f ekscreate.yaml  --approve --override-existing-serviceaccounts
```

## Install add-ons

### aws-load-balancer-contoller

> [Refer to the docs](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html)

```sh
# apply target group binding custom resource
$ kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"

# add eks-charts repository
$ helm repo add eks https://aws.github.io/eks-charts

# update local repo
$ helm repo update

# install aws load balancer contoller
# why image tag v2.1.3 = latest version has bug, not working
$ helm upgrade -i aws-load-balancer-controller eks/aws-load-balancer-controller \
  --set clusterName=spcluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set image.tag=v2.1.3 \
  -n kube-system

# verify
$ kubectl get deployment -n kube-system aws-load-balancer-controller
```

> **Could not find webhook error while using load balancer**

```sh
# Since we don't use webhooks, we can solve it by deleting webhook configuration.
$ kubectl delete validatingwebhookconfiguration aws-load-balancer-webhook
```

### EBS CSI Driver

> [Refer to the docs](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html)

```sh
# add repo
$ helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver

# repo update
$ helm repo update

# install aws ebs csi driver
$ helm upgrade -install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
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
$ kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# verify
$ kubectl get deployment metrics-server -n kube-system
```

### Cluster Autoscaler

> [Refer to the docs](https://docs.aws.amazon.com/eks/latest/userguide/cluster-autoscaler.html)

```sh
# get cluster-autoscaler-autodiscover.yaml file
$ curl -o cluster-autoscaler-autodiscover.yaml https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml

```
> **edit** cluster-autoscaler-autodiscover.yaml 

Deployment.spec.template.spec.containers.command last line : **\<YOUR CLUSTER NAME> -> spcluster**

```sh
# deploy
$ kubectl create -f cluster-autoscaler-autodiscover.yaml

# verify
$ kubectl -n kube-system logs -f deployment.apps/cluster-autoscaler
```

### CloudWatch Container Insights

> [Refer to the docs](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-EKS-quickstart.html)

```sh
# set variables
$ ClusterName=spcluster
$ RegionName=ap-northeast-2
$ FluentBitHttpPort='2020'
$ FluentBitReadFromHead='Off'
$ [[ ${FluentBitReadFromHead} = 'On' ]] && FluentBitReadFromTail='Off'|| FluentBitReadFromTail='On'
$ [[ -z ${FluentBitHttpPort} ]] && FluentBitHttpServer='Off' || FluentBitHttpServer='On'

# deploy
$ curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluent-bit-quickstart.yaml | sed 's/{{cluster_name}}/'${ClusterName}'/;s/{{region_name}}/'${RegionName}'/;s/{{http_server_toggle}}/"'${FluentBitHttpServer}'"/;s/{{http_server_port}}/"'${FluentBitHttpPort}'"/;s/{{read_from_head}}/"'${FluentBitReadFromHead}'"/;s/{{read_from_tail}}/"'${FluentBitReadFromTail}'"/' | kubectl apply -f - 

# verify
$ kubectl get po -n amazon-cloudwatch
```








<br><br><br><br><br>

---
<p align="center">
<h1>CI/CD, Monitoring, Logging</h1>  
</p>

# CI - Github, Dockerhub automated build

> Running nginx in ubuntu environment

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

## Create Dockerfile

```
$ cat Dockerfile
FROM ubuntu:focal
RUN apt-get update
RUN apt-get install -y nginx
WORKDIR /etc/nginx
CMD ["nginx","-g","daemon off;"]
EXPOSE 80
```

## Create git repository

![hi](/img/create_gitrepository01.png)

![hi](/img/create_gitrepository02.png)

## Upload Dockerfile to github

```sh
$ git init
$ git add .
$ git commit -m "init, upload dockfile"
$ git remote add origin <git repositoy address>
$ git branch -M main
$ git push
```

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
$ docker run -itd -p 8080:80 [username]/[repository name]
```

# CD - ArgoCD

> github **deploy** directory

> For this step, the eks cluster environment must be configured first.

> It can be configured by referring to 'Create eks cluster by using clusterconfig file' at the top of this README.

## Create deploy files in deploy directory

```sh
# Collect the files to be deployed in the deploy folder
$ cd deploy

# Manifest for distributing the built dockerfile
$ cat nginx.yaml
apiVersion: apps/v1
kind: Deployment   
metadata:
  name: nginx
spec:
  replicas: 3
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - image: dmsqlczzz/nginx-ubuntu:latest
        name: nginx
        ports:
        - containerPort: 80

# Manifest for service        
$ cat svc.yaml 
apiVersion: v1
kind: Service
metadata:
  name: nginxsvc
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: nginx
```

## Upload deploy directory to github

```sh
$ git init
$ git add .
$ git commit -m "upload deploy directory"
$ git remote add origin <git repositoy address>
$ git branch -M main
$ git push
```

## Set for the ArgoCD environment

```sh
# Create 'argocd' namespace
$ kubectl create namespace argocd

# Install ArgoCD
$ kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Download Argocd CD CLI
$ choco install argocd

# Access the ArgoCD API server
$ kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Find ArcoCD IP address
# argocd service resource - External IP
$ kubectl get all -n argocd

# Get password
$ kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Create ArgoCD app

At chrome secret mode
1. Access to ArgoCD IP address

![hi](/img/access_argocd01.png)

![hi](/img/access_argocd02.png)

2. Login ArgoCD  
   ID : admin
   PW : \<Password found with argocd secret>

![hi](/img/login_argocd.png)

3. Create new app

![hi](/img/argocd_create_app01.png)

![hi](/img/argocd_create_app02.png)

- GENERAL
  - Applicatioin Name : Set as you like
  - Project : default

![hi](/img/argocd_create_app03.png)

- SOURCE
  - Repository URL : your github repository url  
    *You can find it here.*  
    ![hi](/img/argocd_create_app04.png)
  - Path : <
Directory where you put the deploy file>  
    *In my case,* deploy
- DESTINATION
  - Cluster URL : \<cluster with argocd>  
    *If you click this area, you can see the clusters that can be selected.*  
    *In my case,* https://kubernetes.default.svc
  - Namespace : default

***Click CREATE botton***

![hi](/img/argocd_create_app05.png)

## Sync ArgoCD app

1. Click ***SYNC*** button
2. Click ***SYNCHRONIZE*** button

![hi](/img/argocd_sync_app01.png)

If it is well configured, it becomes 'Healthy' and 'Synced' as shown below.

![hi](/img/argocd_sync_app02.png)

If you click on the area shown above, you can check the currently deployed resource configuration as shown below.

![hi](/img/argocd_sync_app03.png)

## Modify the deploy file and check if argocd works well

1. Modify deploy file

```sh
# Modify deploy file
$ cat nginx.yaml
apiVersion: apps/v1
kind: Deployment   
metadata:
  name: nginx
spec:
  replicas: 4 # Modified from 3 to 4
  revisionHistoryLimit: 4 # Modified from 3 to 4
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - image: dmsqlczzz/nginx-ubuntu:latest
        name: nginx
        ports:
        - containerPort: 80
```

2. Make git commit and push

```sh
$ git add .
$ git commit -m "Modify deploy file"
$ git push
```

3. Check if argocd works well

As shown below, check that the nginx pods have changed from 3 to 4.

![hi](/img/argocd_sync_app04.png)

# Monitoring - AWS CloudWatch ContainerInsight

When configuring the EKS cluster, CloudWatch Container Insights and Metrics Server are deployed, so monitoring is possible in the AWS console.

![hi](/img/Monitoring.png)

# Logging - AWS CloudWatch Log

Like monitoring, you can check the logs in AWS CloudWatch.  
Filtering the log group by cluster name and checking the log group of my cluster is as follows.

![hi](/img/logging01.png)

If you click one log group, you can check the log stream as follows.

![hi](/img/logging02.png)

If you click the log stream, you can see the log details and also check the log details.

![hi](/img/logging03.png)


