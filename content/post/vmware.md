---
title: vmware网卡详解
slug: vmware
date: 2019-04-09
categories:
- vmware
- network
tags:
- vmware
- network
autoThumbnailImage: true
metaAlignment: center

---
主要讲述vmware中三种网卡模式以及如何配置双网卡上网。
<!--more-->

<!-- toc -->

> [kubernetes集群三步安装](https://sealyun.com/pro/products/)

## 网卡介绍

### NAT
{{< alert success >}}
网络地址转换,相当于从主机网络中虚拟出一块网卡作为虚拟机的网卡进行上网。
{{< /alert >}}
{{< alert warning >}}
只可以上外网
{{< /alert >}}

效果:

1. 网络模式为自动获取ip模式(非固定ip)
2. 不跟随网络环境的变动而调整网络
3. 虚拟机可访问主机但是主机不能访问虚拟机
4. 虚拟机使用的网卡是虚拟的并非实际网卡

### bridged
{{< alert success >}}
桥接网卡,共享主机的物理网卡,ip必须与物理网卡相同网段,与主机存在于相同的网段。
{{< /alert >}}
{{< alert warning >}}
可以上外网并存在于局域网中
{{< /alert >}}

效果:

1. 共享主机网络,需要和主机网络相同网段
2. 网络模式dhcp或者static均可
3. 虚拟机与宿主机均可互相访问
4. 虚拟机使用的网卡是共享的主机网卡,存在于真实的网络环境中

### host-only
{{< alert success >}}
仅主机网卡,顾名思义只能与主机互联,单独虚拟的网卡可以自建网段。
{{< /alert >}}
{{< alert warning >}}
只能与主机互联即内网环境
{{< /alert >}}

效果:

1. 可自建虚拟网段
2. 网络模式dhcp或者static均可,建议static固定ip
3. 虚拟机与宿主机均可互相访问
4. 虚拟机使用的网卡是用户自建网卡,只存在于内网的网络环境中

## 双网卡设置(nat+hostonly)

{{< alert success >}}
在 VMware -> edit -> Virtual Network Editor 设置网络配置
{{< /alert >}}

### 设置nat网卡

{{< image classes="fancybox right clear" src="/img/vm/nat.png"  title="nat的设置" >}}

### 设置hostonly网卡

{{< image classes="fancybox right clear" src="/img/vm/hostonly.png"  title="hostonly的设置" >}}

### 虚拟机设置双网卡

{{< alert success >}}
虚拟机中设置一张nat网卡一张hostonly网卡,我这里hostonly设置的是172.16.4.0的网段
{{< /alert >}}

nat网卡设置脚本:
{{< codeblock  "net.sh" >}}
nmcli con delete ens36 
nmcli con add autoconnect yes con-name ens36 ifname ens36 type ethernet ipv4.method auto
nmcli con down ens36
nmcli con up ens36
{{< /codeblock >}}

hostonly网卡设置脚本:
{{< alert warning >}}
内网网卡需设置网关为空
{{< /alert >}}

{{< codeblock  "hostonly.sh" >}}
nmcli con delete ens33
nmcli con add autoconnect yes con-name ens33 ifname ens33 type ethernet ipv4.method static ipv4.addresses 172.16.4.254/24 ipv4.gateway ''
nmcli con down ens33
nmcli con up ens33
{{< /codeblock >}}
