---
title: 多网卡配置安装kubeadm
slug: kubernetes/netbrige
date: 2019-03-22
categories:
- kubernetes
tags:
- kubernetes
- kubeadm
- netbrige
autoThumbnailImage: true
metaAlignment: center

---
本文主要讲解如何修改多网卡配置安装kubeadm。
<!--more-->

> [kubernetes集群三步安装](https://sealyun.com/pro/products/)

{{< codeblock  "kubeadm.yaml" >}}
apiVersion: kubeadm.k8s.io/v1beta1
kind: ClusterConfiguration
networking:
  podSubnet: 100.64.0.0/10
kubernetesVersion: v1.13.4
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "ipvs"
---
apiVersion: kubeadm.k8s.io/v1beta1
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: 172.16.3.253
  bindPort: 6443
{{< /codeblock >}}

{{< alert warning >}}
主要修改的参数就是InitConfiguration中的advertiseAddress为自己真实服务器的IP
{{< /alert >}}
