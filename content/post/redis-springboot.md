---
title: 修复springboot下存redis乱码问题
slug: springboot/redis
date: 2019-05-15
categories:
- springboot
- redis
tags:
- springboot
- redis
autoThumbnailImage: true
metaAlignment: center

---
本文主要讲解如何修复springboot下存储redis乱码问题。
<!--more-->

{{< codeblock  "java" >}}
@Bean
public RedisTemplate<String, String> redisTemplate(RedisConnectionFactory factory) {
    StringRedisTemplate template = new StringRedisTemplate(factory);
    //定义key序列化方式
    //RedisSerializer<String> redisSerializer = new StringRedisSerializer();//Long类型会出现异常信息;需要我们上面的自定义key生成策略，一般没必要
    //定义value的序列化方式
    FastJson2JsonRedisSerializer fastJson2JsonRedisSerializer = new FastJson2JsonRedisSerializer<>(Object.class);
    template.setValueSerializer(fastJson2JsonRedisSerializer);
    template.setHashValueSerializer(fastJson2JsonRedisSerializer);
    template.afterPropertiesSet();
    return template;
}
{{< /codeblock >}}
