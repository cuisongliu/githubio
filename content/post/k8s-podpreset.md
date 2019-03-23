---
title: Kubernetes实战之PodPreset
slug: kubernetes/podset
date: 2019-03-22
categories:
- kubernetes
tags:
- kubernetes
- pod
- preset
autoThumbnailImage: true
metaAlignment: center
---
本文主要讲解如何在kubernetes使用pod preset。
<!--more-->

> [kubernetes集群三步安装](https://sealyun.com/pro/products/)

{{< alert warning >}}
可能在某些情况下，您希望 Pod 不会被任何 Pod Preset 突变所改变。在这些情况下，您可以在 Pod 的 Pod Spec 中添加注释：
podpreset.admission.kubernetes.io/exclude："true"。
{{< /alert >}}

为了在集群中使用Pod Preset:
1. 在apiserver参数配置preset相关参数,需要修改/etc/kubernetes/manifests/kube-apiserver.yaml文件
{{< codeblock  "kube-apiserver.yaml" >}}
- --enable-admission-plugins=NodeRestriction,PodPreset
- --runtime-config=settings.k8s.io/v1alpha1=true
{{< /codeblock >}}
2. 在需要配置的namespace中使用PodPreset创建PodPreset资源。
{{< codeblock  "localtime.yaml" >}}
apiVersion: settings.k8s.io/v1alpha1
kind: PodPreset
metadata:
  name: allow-tz-env
  namespace: monitoring
spec:
  volumeMounts:
    - mountPath: /etc/localtime
      name: localtime-config
      readOnly: true
  volumes:
    - name: localtime-config
      hostPath:
        path: /etc/localtime
{{< /codeblock >}}
这样就在monitoring这个命名空间内使用了这个allow-tz-env的PodPreset。这样就会使得该空间内所有的对象都挂载了主机的localtime文件。

{{< alert info >}}
基于之前的lxcfs需要做资源隔离问题这里使用preset解决就很方便了，我们需要使用preset设置一下lxcfs挂载目录即可。
{{< /alert >}}
{{< codeblock  "lxcfs-defalut.yaml" >}}
apiVersion: settings.k8s.io/v1alpha1
kind: PodPreset
metadata:
  name: allow-lxcfs
  namespace: default
spec:
  volumeMounts:
    - mountPath: /proc/cpuinfo
      name: lxcfs-cpuinfo
      readOnly: false
    - mountPath: /proc/diskstats
      name: lxcfs-diskstats
      readOnly: false
    - mountPath: /proc/meminfo
      name: lxcfs-meminfo
      readOnly: false
    - mountPath: /proc/stat
      name: lxcfs-stat
      readOnly: false
    - mountPath: /proc/swaps
      name: lxcfs-swaps
      readOnly: false
    - mountPath: /proc/uptime
      name: lxcfs-uptime
      readOnly: false
  volumes:
    - name: lxcfs-cpuinfo
      hostPath:
        path: /var/lib/lxcfs/proc/cpuinfo
    - name: lxcfs-diskstats
      hostPath:
        path: /var/lib/lxcfs/proc/diskstats
    - name: lxcfs-meminfo
      hostPath:
        path: /var/lib/lxcfs/proc/meminfo
    - name: lxcfs-stat
      hostPath:
        path: /var/lib/lxcfs/proc/stat
    - name: lxcfs-swaps
      hostPath:
        path: /var/lib/lxcfs/proc/swaps
    - name: lxcfs-uptime
      hostPath:
        path: /var/lib/lxcfs/proc/uptime
{{< /codeblock >}}

下面我们创建并查看一下我们创建的preset
{{< codeblock  "bash" >}}
kubectl create -f allow-lxcfs.yaml
kubectl get podpresets.settings.k8s.io 
{{< /codeblock >}}
下面我们需要验证一下，我们启动一个Tomcat的基础镜像查看是否已经生效。
{{< codeblock  "bash" >}}
kubectl run lxcfs-tomcat --image=tomcat:7 --limits='cpu=200m,memory=512Mi'
{{< /codeblock >}}
{{< image classes="fancybox right clear" src="/img/preset/preset.png"  title="preset下的lxcfs效果图" >}}

{{< alert success >}}
到这里我们的preset+lxcfs已经完成配置了。
{{</ alert >}}
