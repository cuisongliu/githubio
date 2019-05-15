---
title: springboot获取req和rep
slug: springboot
date: 2019-05-12
categories:
- springboot
- request
- response
tags:
- springboot
- request
- response
autoThumbnailImage: true
metaAlignment: center

---
本文主要讲解如何在springboot下获取request和response。
<!--more-->

{{< codeblock  "WebUtil.java" >}}
/**
 * 获取 HttpServletRequest
 */
public static HttpServletResponse getResponse() {
    return ((ServletRequestAttributes) RequestContextHolder.getRequestAttributes()).getResponse();
}

/**
 * 获取 HttpServletRequest
 * @return request
 */
public static HttpServletRequest getRequest() {
    return ((ServletRequestAttributes) RequestContextHolder.getRequestAttributes()).getRequest();
}
{{< /codeblock >}}
