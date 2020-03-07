---
title: client-go深入实践
slug: kubernetes/client-go-2
date: 2019-12-01
categories:
- kubernetes
- client-go
tags:
- kubernetes
- client-go
autoThumbnailImage: true
metaAlignment: center
showPagination: false
---
本文主要讲解kubernetes的client的深入了解，最佳实践等等。

<!--more-->

<!-- toc -->

> [kubernetes集群三步安装](https://sealyun.com/pro/products/)

# How to access a kubernetes cluster

- CLI: kubectl
- UI: dashboard
- Access rest api
  - kubectl proxy ; curl localhost:8001/api/v1/namespaces/pods
- Programmatic access
  - client-go
  - other clients (open api)
    - java
    - python
    
# Contents of client-go

- Different client
  - clientset
    - config
      - out of cluster
        - kube-config
        - auth plugin(cloud)
      - in cluster
        - rest.InClusterConfig()   (serviceaccount)
    - use:
      - clientset.Core("namespace").Pods().Create(pod)
  - dynamic client
  - restclient
- writing controllers
  - workqueue
  - informer

# Clients

## Clientset

### Get

![get](/img/client-go/get.png)
{{< codeblock  "go" >}}
type GetOptions struct {	
	// - if unset, then the result is returned from remote storage based on quorum-read flag;
	// - if it's 0, then we simply return what we currently have in cache, no guarantee;
	// - if set to non zero, then the result is at least as fresh as given rv.
	ResourceVersion string 	
}
{{< /codeblock >}}

### List

![list](/img/client-go/get.png)

- ListOptions.ResourceVersion has the same meaning as GetOptions.ResourceVersion
- Informer uses it

### Watch

- starts watching from opt.ResourceVersion
- best practice: always set the ResourceVersion
- api server will time out a watch   5-10 min
{{< codeblock  "go" >}}
options :=api.ListOptions{ResourceVersion:"0"}
list,err :=r.listerWatcher.List(options)
resourceVersion = listMetaInterface.GetResourceVersion()
options = api.ListOptions{
   ResourceVersion : resourceVersion,
}
w,err :=r.listerWatcher.Watch(options)
{{< /codeblock >}}

### Update  &&   UpdateStatus

- optimistic concurrency via cap (compare and swap)

### Patch

- merge
- safe for unknown fields
- retry 5 times at server
- best practice: always set the origina uid in the patch
  - namespace+name is not unique across time

### Delete

- DeleteOptions.Preconditions
  - uid : namespace+name is not unique across time
- DeleteOptions.PropagationPolicy
  - Orphan : not delete dependents resource,only delete current controller.
  - Background: delete current controller,other dependents resource gc delete.
  - Foreground: delete current controller must be delete dependents resource.

## Dynamic client

- example
  - ret,err:=client.Reource(resource,namespace).Get(name)
  - ret is of type map[string]interface{}
  - structured access to ObjectMet, e.g., ret.GetUID()
- used extensively in pkg/controller/<namespace,garbagecontrollector>
- crd
- only support json, json < protobuf

## RESTClient

- example
  - var ret v1.Pod
    err:= c.rest.Get().Resource("pods").Namespace(namespace).Do().Into(&ret)
  - ret is typed
  - DoRaw() return byte[]
- base of clientset and dynamic client
- supports json and proto
- need to satisfy the api machinery
