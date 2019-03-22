---
title: containerd与kubernetes集成
slug: kubernetes
date: 2019-03-12
categories:
- kubernetes
tags:
- kubernetes
- containerd
autoThumbnailImage: true
thumbnailImagePosition: "top"
metaAlignment: center
thumbnailImage: img/k8s-containerd/containerd-color.png

---
本文主要讲解如何将kubernetes中的docker替换为containerd。并讲解关于容器相关的基础概念。
以及相关部署配置说明。<br/>
由于docker嵌入了太多自身内容,为了减轻容器负担。此次选用containerd作为kubernetes的容器实现方案。本文将带大家讲述如何搭建一个集成了containerd的k8s集群。
<!--more-->

<!-- toc -->

> [kubernetes集群三步安装](https://sealyun.com/pro/products/)


## 概念介绍

- cri (Container runtime interface)
  - `cri` is a [containerd](https://containerd.io/) plugin implementation of Kubernetes [container runtime interface (CRI)](https://github.com/kubernetes/kubernetes/blob/master/pkg/kubelet/apis/cri/runtime/v1alpha2/api.proto).
  - cri是 kubernetes的容器运行时接口的容器插件实现。
  - ![CRI](/img/k8s-containerd/cri.png)
- containerd
  - containerd is an industry-standard container runtime with an emphasis on simplicity, robustness and portability.
  - containerd完全支持运行容器的的CRI运行时规范。
  - cri在containerd1.1以上的版本的原生插件。它内置于containerd并默认启用。
  - ![containerd](https://gogs.cuisongliu.com/cuisongliu/cuisongliu-github/raw/master/static/img/k8s-containerd/containerd.png)

- cri-o
  - OCI-based implementation of Kubernetes Container Runtime Interface.
  - kubernetes为了兼容cri和oci孵化了项目cri-o。为了架设在cri和oci之间的一座桥梁。由此cri-o既兼容cri插件实现又兼容oci的容器运行时标准。

- oci (Open Container Initiative)
  - https://www.opencontainers.org/about/oci-scope-table
  - oci是由多家公司成立的项目,并由linux基金会进行管理,致力于container runtime 的标准的制定和runc的开发等工作。

- runc
  - `runc` is a CLI tool for spawning and running containers according to the OCI specification.
  - runc，是对于OCI标准的一个参考实现，是一个可以用于创建和运行容器的CLI(command-line interface)工具。

  ![kubelet](https://gogs.cuisongliu.com/cuisongliu/cuisongliu-github/raw/master/static/img/k8s-containerd/kubelet.png)

## 环境准备

下载containerd二进制包。我这里已经编译并打包了好了，内含containerd、runc、crictl、ctr等。

下载链接：[containerd-v1.2.4.tar.gz](https://github.com/cuisongliu/containerd-dist/releases/download/v1.2.4/containerd-v1.2.4.tar.gz)

- runc版本：  1.0.1-dev
- containerd版本： v1.2.4

## 安装

### 安装containerd

- 解压二进制包并生成默认文件

    {{< codeblock  "bash" >}}
tar -C /usr/local/bin -xzf containerd-v1.2.4.tar.gz
chmod a+x /usr/local/bin/*
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
    {{< /codeblock >}}
    {{< alert warning >}}
生成的默认配置文件注意  [grpc] 的 address 字段默认为 /run/containerd/containerd.sock
    {{</ alert >}}
    配置文件其他参数含义参照github地址： [containerd-config.md](https://github.com/containerd/containerd/blob/master/docs/man/containerd-config.toml.5.md)

- 在  `/etc/systemd/system` 目录下编写文件  `containerd.service`内容如下:
    
    {{< codeblock  "containerd.service" >}}
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/usr/local/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
    {{< /codeblock >}}

- 启动containerd

    {{< codeblock  "bash" >}}
systemctl enable containerd
systemctl restart containerd
systemctl status containerd
    {{< /codeblock >}}

    看containerd启动状态如果是running就没有问题。下面我们测试拉取一下hub的镜像。

- 测试containerd
    {{< codeblock  "bash" >}}
ctr images pull docker.io/library/nginx:alpine
    {{< /codeblock >}}

    看到输出done，说明containerd运行一切正常。

### 使用crictl连接containerd


>  下一步我们使用crictl连接containerd。


- 修改crictl的配置文件,在  `/etc/crictl.yaml` 写入以下内容：

    {{< codeblock  "yaml`" >}}
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
    {{< /codeblock >}}

    这里注意runtime-endpoint 和image-endpoint 必须与/etc/containerd/config.toml中配置保持一致。

- 验证一下cri插件是否可用

    {{< codeblock  "bash" >}}
crictl  pull nginx:alpine
crictl  rmi  nginx:alpine
crictl  images
    {{< /codeblock >}}
    其中   `crictl  images`  会列出所有的cri容器镜像。

    到此我们的cri + containerd已经完成整合了。下一步我们需要修改kubeadm配置进行安装。

### containerd部署脚本
{{< alert success >}}
到此我特意重新整理了部署脚本,包括containerd,ctr,circtl等配置。具体详细配置请移步[containerd-dist](https://github.com/cuisongliu/containerd-dist)
{{< /alert >}}


### 导入kubenetes离线镜像包（kubernetes调整）
{{< alert danger >}}
这里我们就需要导入k8s的离线镜像包了。**这里需要注意一下，kubernetes是调用的cri接口,所以导入时也需要从cri插件导入镜像。**
{{< /alert >}}

- cri导入镜像命令(cri导入镜像)：

  ```shell
   ctr cri load  images.tar
  ```

- containerd导入镜像命令(containerd导入镜像)：

  ```
   ctr images import images.tar 
  ```

### 修改kubelet配置和kubeadm安装时配置（kubernetes调整）

- 在 kubelet配置文件 10-kubeadm.conf 的`[Service]` 结点加入以下配置：

    {{< codeblock  "conf" >}}
  Environment="KUBELET_EXTRA_ARGS=--container-runtime=remote --runtime-request-timeout=15m --container-runtime-endpoint=unix:///run/containerd/containerd.sock"
    {{</ codeblock>}}

- 在kubeadm配置文件 kubeadm.yaml 中加入

    {{< codeblock  "yaml" >}}
apiVersion: kubeadm.k8s.io/v1beta1
kind: InitConfiguration
nodeRegistration:
  criSocket: /run/containerd/containerd.sock
  name: containerd
    {{</ codeblock>}}


  到此containerd和kubernetes的集成就完成了。下面可以直接安装即可。
  
