---
title: 利用LXCFS增强容器隔离性和资源可见性
slug: docker/lxcfs
date: 2019-03-22
categories:
- docker
tags:
- docker
- cgroup
- lxcfs
autoThumbnailImage: true
metaAlignment: center

---
本文主要讲解如何使用lxcfs增强容器的隔离性和可见性。并使用二进制部署包使用，减轻部署难度。可在离线环境中使用。
<!--more-->

> [kubernetes集群三步安装](https://sealyun.com/pro/products/)

{{< alert info >}}
基于LXCFS增强docker容器隔离性的分析
https://blog.csdn.net/s1234567_89/article/details/50722915

Kubernetes之路 2 - 利用LXCFS提升容器资源可见性
https://yq.aliyun.com/articles/566208
{{< /alert >}}


使用二进制lxcfs包进行安装部署，下载地址为：
https://github.com/cuisongliu/lxcfs/releases/download/lxcfs-3.0.3-binary-install/lxcfs.tar.gz
{{< alert warning >}}
确保系统中是否有fusermount命令,系统使用fusermount进行卸载挂载点。
{{< /alert >}}

安装如图：

{{< image classes="fancybox right clear" src="/img/lxcfs/lxcfs.png"  title="lxcfs安装步骤" >}}

操作是不是很easy?下面我们对比一下效果。

首先是在没有安装lxcfs的主机上执行命令：
{{< codeblock  "bash" >}}
docker run --rm -ti  -m 200m ubuntu bash
free -m
{{< /codeblock >}}
效果如图所示：
{{< image classes="fancybox right clear" src="/img/lxcfs/lxcfs-0.png"  title="未使用lxcfs效果图" >}}
接下来我们在安装了lxcfs的主机上同样执行命令
{{< codeblock  "bash" >}}
docker run --rm -it -m 200m \
      -v /var/lib/lxcfs/proc/cpuinfo:/proc/cpuinfo:rw \
      -v /var/lib/lxcfs/proc/diskstats:/proc/diskstats:rw \
      -v /var/lib/lxcfs/proc/meminfo:/proc/meminfo:rw \
      -v /var/lib/lxcfs/proc/stat:/proc/stat:rw \
      -v /var/lib/lxcfs/proc/swaps:/proc/swaps:rw \
      -v /var/lib/lxcfs/proc/uptime:/proc/uptime:rw \
      ubuntu bash
{{< /codeblock >}}
效果如图所示：
{{< image classes="fancybox right clear" src="/img/lxcfs/lxcfs-1.png"  title="使用lxcfs效果图" >}}
到这里lxcfs已经生效了。

{{< alert success >}}
这里讲解了docker的使用,对于k8s用户建议使用 https://github.com/fanux/kube/releases/tag/v.12.5-lxcfs-gate
替换k8s的kebelet即可。
{{< /alert >}}
