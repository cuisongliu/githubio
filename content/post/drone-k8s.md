---
title: 利用drone构建ci/cd系统，对接k8s
slug: drone/k8s
date: 2019-04-03
categories:
- drone
- kubernetes
tags:
- kubernetes
- drone
- devops
autoThumbnailImage: true
metaAlignment: center

---
主要讲述如果使用github和drone进行代码环境下的ci/cd环境。
<!--more-->
<!-- toc -->

> [kubernetes集群三步安装](https://sealyun.com/pro/products/)

{{< alert info >}}
基于drone构建CI/CD系统,对接k8s
https://sealyun.com/post/ci-cd/
{{< /alert >}}

直接进入主题,主要使用[drone-kube](https://github.com/cuisongliu/drone-kube)插件进行drone的k8s部署。
该插件主要包括两大功能,初始化kubeconfig文件和渲染部署k8s相关文件。

# kubeconfig文件渲染

{{< alert warning >}}
使用命令模式drone-kube config进行kubeconfig文件渲染管理员文件,使用命令模式drone-kube configToken进行kubeconfig文件渲染用户token管理文件。
{{< /alert >}}

#### 管理员模式

{{< alert info >}}
该模式为最常见的kubernetes-admin管理方式。
{{< /alert >}}

{{< codeblock  ".drone.yml" >}}
- name: deploy-font
  image: cuisongliu/drone-kube
  settings:
    server:
      from_secret: k8s-server
    ca:
      from_secret: k8s-ca
    admin:
      from_secret: k8s-admin
    admin_key:
      from_secret: k8s-admin-key
  commands:
    - drone-kube config  >> /dev/null
    - kubectl delete -f deploy/deploy.yaml || true
    - sleep 15
    - kubectl create -f deploy/deploy.yaml || true
{{< /codeblock >}}

#### 多租户模式

{{< alert info >}}
该模式为kubernetes下发user-token的模式。
{{< /alert >}}

{{< codeblock  ".drone.yml" >}}
- name: deploy-font
  image: cuisongliu/drone-kube
  settings:
    server:
      from_secret: k8s-server
    user:
      from_secret: k8s-user
    token:
      from_secret: k8s-token
  commands:
    - drone-kube configToken  >> /dev/null
    - kubectl delete -f deploy/deploy.yaml || true
    - sleep 15
    - kubectl create -f deploy/deploy.yaml || true
{{< /codeblock >}}

# 部署文件模板渲染

{{< alert warning >}}
1. 编写部署模板文件,必须以yaml.tmpl或者yml.tmpl为文件结尾。其中变量名称需要为TEMPLATE开头且必须为大写如TEMPLATE_TAG1。
2. drone的脚本中变量名与模板文件中变量需要保持一致,大小写亦可。
3. 脚本drone-kube template --deploy=deploy为渲染模板命令,需要手动执行。其中deploy参数为存放模板文件的目录。
{{< /alert >}}

{{< codeblock  "deploy.yaml.tmpl" >}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{.TEMPLATE_TAG1}}
  labels:
    app: {{.TEMPLATE_TAG1}}
spec:
  replicas: 1
  template:
    metadata:
      name: {{.TEMPLATE_TAG1}}
      labels:
        app: {{.TEMPLATE_TAG1}}
    spec:
      containers:
        - name: {{.TEMPLATE_TAG1}}
          image: {{.TEMPLATE_TAG2}}
          imagePullPolicy: IfNotPresent
      restartPolicy: Always
  selector:
    matchLabels:
      app: {{.TEMPLATE_TAG1}}
{{< /codeblock >}}        

{{< codeblock  ".drone.yml" >}}
- name: deploy-font
  image: cuisongliu/drone-kube
  settings:
    server:
      from_secret: k8s-server
    ca:
      from_secret: k8s-ca
    admin:
      from_secret: k8s-admin
    admin_key:
      from_secret: k8s-admin-key
    template_tag1: alpine
    template_tag2: ${DRONE_TAG=drone-test}
  commands:
    - drone-kube config
    - drone-kube template --deploy=deploy >> /dev/null
    - kubectl delete -f deploy/deploy.yaml || true
    - sleep 15
    - kubectl create -f deploy/deploy.yaml || true
{{< /codeblock >}}  
