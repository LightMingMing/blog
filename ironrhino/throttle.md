# 流量控制
`Ironrhino`框架`org.ironrhino.core.throttle`中, 提供了许多流量控制的手段, 在Spring组件的方法上标注相关注解, 即可直接使用. 
## Bulkhead挡板
### 使用
`@Bulkhead`, 用于**单机并发量**控制  

| 属性 | 说明 | 默认值 |
| ---- | ---- | ---- |
| `maxConcurrentCalls` | 最大并发数, `@Bulkhead`标注的方法在任意时刻的并发数量都不会超过该值 | 50 |
| `maxWaitTime`| 最大等待时间(ms): 并发量达到最大值时, 线程的最大的阻塞时间, 超时后, 会抛`BulkheadFullException`异常 | 0 |

```java
import org.ironrhino.core.throttle;
public @interface Bulkhead {
	int maxConcurrentCalls() default 50;
	long maxWaitTime() default 0; // ms
}
```
### 实现
借助于`resilience4j`开源节流工具进行实现的
```java
package org.ironrhino.core.throttle;

@Aspect
@Component
@ClassPresentConditional("io.github.resilience4j.bulkhead.Bulkhead")
public class BulkheadAspect extends BaseAspect {
    
    // ...

	@Around("execution(public * *(..)) and @annotation(bulkhead)")
	public Object control(ProceedingJoinPoint jp, Bulkhead bulkhead) throws Throwable {
		String key = buildKey(jp);
		io.github.resilience4j.bulkhead.Bulkhead bh = bulkheads.computeIfAbsent(key, k -> {
			BulkheadConfig config = BulkheadConfig.custom().maxConcurrentCalls(bulkhead.maxConcurrentCalls())
					.maxWaitTime(bulkhead.maxWaitTime()).build(); // bulkhead构建
			return io.github.resilience4j.bulkhead.Bulkhead.of(k, config);
		});
		BulkheadUtils.isCallPermitted(bh);
		try {
			return jp.proceed();
		} finally {
			bh.onComplete();
		}
	}
}
```
更深一步, 在`resilience4j`中, `Bulkhead`则是借助Java中`Semaphore`信息进行实现的.  
最大并发数, 也就是`Semaphore`初始化时许可的个数; 方法执行前获取许可, 方执行后释放许可;
```java
package io.github.resilience4j.bulkhead.internal;
public class SemaphoreBulkhead implements Bulkhead {
    // ...
    private final Semaphore semaphore;
    // ...

    boolean tryEnterBulkhead() {
        boolean callPermitted = false;
        long timeout = this.config.getMaxWaitTime(); // 最大等待时间
        if (timeout == 0L) {
            callPermitted = this.semaphore.tryAcquire(); // 获取许可
        } else {
            try {
                callPermitted = this.semaphore.tryAcquire(timeout, TimeUnit.MILLISECONDS); // 限时获取
            } catch (InterruptedException var5) {
                callPermitted = false;
            }
        }

        return callPermitted;
    }

    public void onComplete() {
        this.semaphore.release(); // 方法执行完毕, 许可的释放
        this.publishBulkheadEvent(() -> {
            return new BulkheadOnCallFinishedEvent(this.name);
        });
    }

}
```

## Concurrency并发量
### 使用
`@Concurrency`支持**单机、多机并发量**的控制  

| 属性 | 说明 | 默认值 |
| ---- | ---- | ---- |
| `key` | 键值 | |
| `permits`| 最大并发数 | |
| `block`| 是否阻塞. `false`, 达到超时时间后, 会抛`IllegalConcurrentAccessException`异常; `true`, 会永久阻塞直到获取许可成功. 这里有点歧义, `false`的阻塞是阻塞一段时间(下面两个属性), `true`是一直阻塞  | `false` |
| `timeout` | `block`为`false`时, 超时时间 | 0 | 
| `timeunit` | 时间单位 | `TimeUnit.MILLISECONDS`毫秒 |

```java
import org.ironrhino.core.throttle;
public @interface Concurrency {
	String key() default "";
	String permits();
	boolean block() default false;
	int timeout() default 0;
	TimeUnit timeUnit() default TimeUnit.MILLISECONDS;
}
```
### 实现
单机并发控制, 实现和`Bulkhead`比较相似, 超时时间也就是`Bulkhead`中的最大等待时间, 都是借助于`Semaphore`信号量进行实现的
```java
package org.ironrhino.core.throttle.impl;

@Component("concurrencyService")
@ServiceImplementationConditional(profiles = DEFAULT)
public class StandaloneConcurrencyService implements ConcurrencyService {
    
	@Override
	public boolean tryAcquire(String name, int permits, long timeout, TimeUnit unit) throws InterruptedException {
		return getSemaphore(name, permits).tryAcquire(timeout, unit); // 限时阻塞获取
	}

    @Override
	public void acquire(String name, int permits) throws InterruptedException {
		getSemaphore(name, permits).acquire(); // 永久阻塞获取
	}

	@Override
	public void release(String name) {
		Semaphore semaphore = semaphores.get(name); 
		if (semaphore == null)
			throw new IllegalArgumentException("Semaphore '" + name + " ' doesn't exist");
		semaphore.release(); // 许可释放
	}
}
```
多机并发量控制, 借助于`Redis`实现, 详见`org.ironrhino.core.throttle.impl.RedisConcurrencyService`.  
这里实现的方式比较巧妙: 获取许可前, 调用redis的自增操作，根据返回值大小来判断获取许可是否成功，如果获取失败，则进行自增(-1)操作, 以恢复之前状态; 如果获取成功，在方法执行完后，再释放许可(进行-1操作). 如果是限时阻塞获取或永久阻塞获取, 则睡眠100ms后, 继续重复该操作.
```java
// 许可的获取
Long value = throttleStringRedisTemplate.opsForValue().increment(key, 1);
boolean success = value != null && value.intValue() <= permits;
if (!success)
    throttleStringRedisTemplate.opsForValue().increment(key, -1); // 恢复之前状态
```
```java
// 许可的释放
throttleStringRedisTemplate.opsForValue().increment(key, -1);
```

## Frequency频率

## RateLimiter频率

## CircuitBreaker断路器

## Mutex互斥