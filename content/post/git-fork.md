---
title: github提交流程
slug: git/commit
date: 2019-11-10
categories:
- git
tags:
- git
- commit
- fork
autoThumbnailImage: true
metaAlignment: center
showPagination: false
---
本文主要讲解如何使用github提交代码到开源仓库。以github比较有代表性来说明一下github的fork代码开发流程，同样适用于git相关的代码仓库例如gitlab或者gogs等相关的代码仓库。
<!--more-->

<!-- toc -->

# 提交代码流程

- fork代码仓库

  - 找到目标代码库例如 <https://github.com/fanux/sealos> 仓库点击fork按钮将需要进行开发的代码仓库fork到当前的用户。![Fork](/img/git/fork.png)

  

- 新建分支开发代码

  - 克隆需要开发的代码仓库到本地例如本地用户为cuisongliu 那么clone的仓库地址就是 https://github.com/cuisongliu/sealos.git

  - 基于需要开发的分支克隆出新分支3.0-local例如开发分支为3.0.0 那么克隆后需要在本地执行

    ```shell
    git checkout  3.0.0
    git checkout  -b 3.0-local
    ```

  - 在新建分支上直接开发代码并提交到新分支3.0-local

    ```shell
    git add *
    git commit -m "init code"
    git push origin 3.0-local
    ```

  - 在界面上就会出现新的分支![Branch](/img/git/branch.png)

- 提交pull request流程

  - 进入仓库链接<https://github.com/cuisongliu/sealos/pulls>可以新建pr。切记这里的仓库和分支需要选择正确：从cuisongliu账户同步代码到fanux账户仓库。同时可以看到代码变更选择何人review代码等等操作。![PR](/img/git/pr.png)
  - 创建pr后主仓库的参与者即可接收到pr请求。可以对提交的pr进行操作是否merge还是拒绝pr操作。

- 注意流程

  - 在push代码时需要用户先同步base代码(即3.0.0分支)，保证base主线代码一致。
  - 在push代码时需要把base代码merge到新分支后在push，保证代码分支一致。merge教程请参照<https://git-scm.com/book/zh/v1/Git-%E5%88%86%E6%94%AF-%E5%88%86%E6%94%AF%E7%9A%84%E6%96%B0%E5%BB%BA%E4%B8%8E%E5%90%88%E5%B9%B6>

# 同步代码流程

- 使用pull request流程同步代码
  - 进入源仓库地址<https://github.com/fanux/sealos/pulls> 可以新建同步pr。目标地址为开发项目的base代码库以及分支。![PR](/img/git/pr1.png)
- merge代码到新分支代码
  - 同步之后的base代码分支的代码需要merge到新分支代码。