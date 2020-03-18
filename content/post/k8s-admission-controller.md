---
title: kubernetes 之 admission controller原理 (未完成)
slug: kubernetes/admission-controller
date: 2020-03-06
categories:
- kubernetes
- admission
- controller
tags:
- kubernetes
- admission-controller
autoThumbnailImage: true
metaAlignment: center
showPagination: false
---
本文主要讲解kubernetes的admission controller调用过程，以及原理设计。

<!--more-->

<!-- toc -->

> [kubernetes集群三步安装](https://sealyun.com/pro/products/)

{{< image classes="fancybox right clear" src="/img/admission-controller/0apiserver.png"  title="APIServer工作组件" >}}
{{< alert info >}}
APIServer其实最重要的三件事情就是：
- 认证: 用户是否合法
- 授权: 用户拥有哪些权限
- 准入控制: 一个调用链，对请求进行修改或拒绝
{{< /alert >}}

这个准入控制器是十分有用的，也是kubernetes一种比较常见的扩展方式。现在，我们将详细的介绍一下这个admission controller。

{{< codeblock "plugins.go" "go" "https://github.com/kubernetes/kubernetes/blob/575467a0eaf3ca1f20eb86215b3bde40a5ae617a/pkg/kubeapiserver/options/plugins.go#L129" "plugins.go" >}}
// 默认关闭的plugin
func DefaultOffAdmissionPlugins() sets.String {
	//定义默认开启的插件
	defaultOnPlugins := sets.NewString(
		lifecycle.PluginName,                //NamespaceLifecycle
		limitranger.PluginName,              //LimitRanger
		serviceaccount.PluginName,           //ServiceAccount
		setdefault.PluginName,               //DefaultStorageClass
		resize.PluginName,                   //PersistentVolumeClaimResize
		defaulttolerationseconds.PluginName, //DefaultTolerationSeconds
		mutatingwebhook.PluginName,          //MutatingAdmissionWebhook
		validatingwebhook.PluginName,        //ValidatingAdmissionWebhook
		resourcequota.PluginName,            //ResourceQuota
	)
	//根据feature是否支持，来决定plugin是否启用
	if utilfeature.DefaultFeatureGate.Enabled(features.PodPriority) {
		defaultOnPlugins.Insert(podpriority.PluginName) //PodPriority
	}
	if utilfeature.DefaultFeatureGate.Enabled(features.TaintNodesByCondition) {
		defaultOnPlugins.Insert(nodetaint.PluginName) //TaintNodesByCondition
	}
	//排除所有的默认开启插件，其余的为默认关闭插件
	return sets.NewString(AllOrderedPlugins...).Difference(defaultOnPlugins)
}

{{< /codeblock >}}

这里看到默认开启的admission controller:

|  名称  | 作用   | 
|:----------:|------------|
| NamespaceLifecycle | 确保处于termination状态的namespace不再接收任何新对象的请求，并拒绝请求不存在的namespace。 | 
| LimitRanger | 在多租户配额时相当有用，如果pod没配额，那么我可以默认给个很低的配额 |
| ServiceAccount | 在pod没有设置serviceAccount属性时,将这个pod的sa设置为"default";在安全环境下使用，因为default这个sa的权限是admin权限。| 
| DefaultStorageClass | 默认存储类型 |
| PersistentVolumeClaimResize| 检查传入的 PersistentVolumeClaim 调整大小请求，对其执行额外的验证操作。（注意：对调整卷大小的支持是一种 Alpha 特性。管理员必须将特性门控 ExpandPersistentVolumes 设置为 true 才能启用调整大小。）|
| DefaultTolerationSeconds | 设置POD的默认forgiveness toleration为5分钟。|
| MutatingAdmissionWebhook | 变更准入控制webhook|
| ValidatingAdmissionWebhook| 验证准入控制webhook|
| ResourceQuota | 多租户配额时比较重要，看资源是否满足resource quota中的配置|

{{< alert warning >}}
这里有两个比较特殊的控制器:MutatingAdmissionWebhook 和 ValidatingAdmissionWebhook。
{{< /alert >}}
{{< alert success >}}
这两个控制器将发送准入请求到外部的 HTTP 回调服务并接收一个准入响应。如果启用了这两个准入控制器，Kubernetes 管理员可以在集群中创建和配置一个 admission webhook。
{{< /alert >}}
