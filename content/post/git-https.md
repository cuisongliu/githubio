---
title: git连接https仓库
slug: git/https
date: 2019-03-10
categories:
- git
tags:
- git
- https
autoThumbnailImage: true
metaAlignment: center
showPagination: false
---
本文主要讲解如何解决git连接https仓库出现报错的问题。该问题主要出现在Debian以及Ubuntu等操作系统中。
<!--more-->

<!-- toc -->

{{< alert warning >}}
在Debian等操作系统使用git clone 经常出现```error: gnutls_handshake() failed: A TLS packet with unexpected length was received``` 错误。
{{< /alert >}}

### 使用http克隆仓库

{{< codeblock  "bash" >}}
#!/bin/bash
git clone http://github.com/cuisongliu/xxx
{{< /codeblock >}}


### 使用git源码重新编译

{{< codeblock  "bash" >}}
#!/bin/bash
git clone http://github.com/git/git.git
sudo apt-get install libcurl4-openssl-dev
{{< /codeblock >}}
这时系统会把 libcurl4-gnutls-dev 換成 libcurl4-openssl dev,接下来需要用户重新编译源码即可

{{< codeblock  "bash" >}}
make configure
./configure  --prefix=/usr/local
make all doc
make install install-doc install-html
{{< /codeblock >}}
