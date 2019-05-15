---
title: 在springboot下利用aspect实现重复提交验证
slug: springboot/resubmit
date: 2019-05-11
categories:
- springboot
- aop
- resubmit
tags:
- springboot
- resubmit
autoThumbnailImage: true
metaAlignment: center

---
本文主要说明使用aspect+redis实现重复提交的校验。
<!--more-->

### 注解声明

{{< codeblock  "Resubmit.java" >}}
@Target({ElementType.METHOD})
@Retention(RetentionPolicy.RUNTIME)
@Documented
public @interface Resubmit {
    /**
     *
     * @return default cache key
     */
    String cacheKey() default "default";

    /**
     *
     * @return timeout default unit is seconds
     */
    long timeout() default  10L;
}
{{< /codeblock >}}

### 切面设计

{{< codeblock  "ResubmitAspect.java" >}}
@Aspect
@Component
@Slf4j
public class ResubmitAspect {
    @Autowired
    @Qualifier("redisCacheService")
    private CacheService cacheService;

    @Pointcut("@annotation(Resubmit)")
    public void pointcut() {
    }

    private static final String prefix = ":resubmit:";

    @Around(value = "pointcut()")
    public Object around(ProceedingJoinPoint pjp) throws Throwable {
        Resubmit resubmit = getResubmitAnn(pjp);
        //TODO 这里需要根据情况替换掉session_id
        String cachekey = resubmit.cacheKey()+":"+"session_id";
        Object obj =null;
        if (!getExcelRedis(cachekey)) {
            obj = pjp.proceed();
            setExcelRedis(cachekey,resubmit.timeout());
        } else {
            throw new ApiException(ApiErrorCode.OPERATOR_TOO_FAST);
        }
        return obj;
    }

    private Boolean getExcelRedis(String cacheKey) {
        Optional<Object> excelFlag = cacheService.get(prefix + cacheKey);
        Object excel = excelFlag.orElse(null);
        Boolean returnExcel;
        log.info(String.valueOf(excel));
        if (excel == null) {
            returnExcel = false;
        } else {
            returnExcel = Boolean.valueOf(excel.toString());
        }
        return returnExcel;
    }

    private void setExcelRedis(String cacheKey, Long timeOut) {
        cacheService.put(prefix + cacheKey, true, timeOut, TimeUnit.SECONDS);
    }

    private Resubmit getResubmitAnn(ProceedingJoinPoint joinPoint)
            throws Exception {
        String targetName = joinPoint.getTarget().getClass().getName();
        String methodName = joinPoint.getSignature().getName();
        Object[] arguments = joinPoint.getArgs();
        Class targetClass = Class.forName(targetName);
        Method[] methods = targetClass.getMethods();
        Resubmit resubmit = null;
        for (Method method : methods) {
            if (method.getName().equals(methodName)) {
                Class[] clazzs = method.getParameterTypes();
                if (clazzs.length == arguments.length) {
                    resubmit = method.getAnnotation(
                            Resubmit.class);
                    break;
                }
            }
        }
        return resubmit;
    }

}
{{< /codeblock >}}