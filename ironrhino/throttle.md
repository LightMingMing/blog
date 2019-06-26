# 流量控制
`Ironrhino`框架`org.ironrhino.core.throttle`中, 提供了许多流量控制的手段, 在Spring组件的方法上标注相关注解, 即可直接使用. 
## Bulkhead挡板
### 使用
`@Bulkhead`, 用于**单机并发量**控制  

| 属性 | 说明 | 默认值 |
| ---- | ---- | ---- |
| maxConcurrentCalls | 最大并发数, @Bulkhead标注的方法在任意时刻的并发数量都不会超过该值 | 50 |
| maxWaitTime| 最大等待时间(ms): 并发量达到最大值时, 线程的最大的阻塞时间, 超时后, 会抛BulkheadFullException异常 | 0 |

```java
import org.ironrhino.core.throttle;
public @interface Bulkhead {
	int maxConcurrentCalls() default 50;
	long maxWaitTime() default 0; // ms
}
```
### 实现
借助于开源容错框架`resilience4j`进行实现的
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
| key | 键值 | |
| permits | 最大并发数 | |
| block | 是否阻塞. false达到超时时间后, 会抛IllegalConcurrentAccessException异常; true会永久阻塞直到获取许可成功. 这里有点歧义, false的阻塞是阻塞一段时间(下面两个属性), true是一直阻塞  | false |
| timeout | block为false时, 超时时间 | 0 | 
| timeunit | 时间单位 | TimeUnit.MILLISECONDS |

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
### 使用
`@Frequency`, 控制一段时间窗口内方法的访问次数, 支持多机

| 属性 | 说明 | 默认值 |
| ---- | ---- | ---- |
| key | 键值 | 默认值 |
| limits | 最大访问次数, 超过该值时将抛FrequencyLimitExceededException | |
| duration | 时间窗口长度 | 1 |
| timeUnit | 时间单位 | TimeUnit.HOURS |

```java
package org.ironrhino.core.throttle;

public @interface Frequency {
	String key() default "";
	String limits();
	int duration() default 1;
	TimeUnit timeUnit() default TimeUnit.HOURS;
}
```
### 实现
以每个时间窗口开始时间戳作为`Redis`缓存中key值的一部分, 之后做自增操作, 根据其返回值来判断是否超过最大访问次数
```java
// FrequencyAspect.java
long timestamp = System.currentTimeMillis();
long duration = frequency.timeUnit().toMillis(frequency.duration());
String actualKey = key + ":" + (timestamp - timestamp % duration);
int limits = ExpressionUtils.evalInt(frequency.limits(), context, 0);
int used = (int) cacheManager.increment(actualKey, 1, frequency.duration(), frequency.timeUnit(), NAMESPACE);
if (limits >= used) {
	return jp.proceed();
} else {
	throw new FrequencyLimitExceededException(key);
}
```

## RateLimiter频率
### 使用
`@RateLimiter` 用于单机访问频度的控制

| 属性 | 说明 | 默认值 |
| ---- | ---- | ---- |
| timeoutDuration | 超时时间  | 5000ms |
| limitRefreshPeriod | 刷新周期 | 500ms |
| limitForPeriod | 周期内最大访问次数 | 100 |

```java
public @interface RateLimiter {
	long timeoutDuration() default 5000; // ms
	long limitRefreshPeriod() default 500; // ms
	int limitForPeriod() default 100;
}
```
### 实现
借助于`resilience4j`实现的, 其实现原理与`@Frequency`类似, 只不过是一个将当前时间窗口并发信息存到了内存中, 令一个是存放到Redis缓存中. 不过由于`RateLimiter`支持超时时间, 在实现上会更加复杂(当前时间窗口的并发量达到最大值时, 之后的访问可以延迟到后面的时间窗口中(如果超时时间够长), 也就是会预先占用后面时间窗口的访问许可)

`resilience4j`将访问信息封装到`state`中, 每次调用`AtomicRateLimiter#getPermission(Duration)}`时, 都会原子更新`state`.
* `activeCycle` 上次访问时的周期数
* `activePermissions` 上次访问时剩余的许可数量
* `nanosToWait` 上一次访问等待时间的纳秒值
至于其它部分, 这里不在细述, 详见`AtomicRateLimiter`.

```java
package io.github.resilience4j.ratelimiter.internal;
public class AtomicRateLimiter implements RateLimiter {
    // ...
	private final AtomicReference<State> state;
	// ...
	private static class State {
		private final RateLimiterConfig config;

		private final long activeCycle;
		private final int activePermissions;
		private final long nanosToWait;

		private State(RateLimiterConfig config,
						final long activeCycle, final int activePermissions, final long nanosToWait) {
			this.config = config;
			this.activeCycle = activeCycle;
			this.activePermissions = activePermissions;
			this.nanosToWait = nanosToWait;
		}
	}
}
```

## CircuitBreaker断路器
### 概述
断路器在电路领域, 是一种用于保护电路的开关. 在电路异常时, 通过自动断开电路来保护电路中电器.  
类似的原理，在应用中如果程序频繁出错到达阈值, 那么就会直接抛断路异常, 而不会继续试错, 从而保护应用.  
断路器有三个状态:
1. 关闭状态: 应用正常工作
2. 打开状态: 应用频繁出错到达阈值, 断路器则由关闭状态变为打开状态
3. 半开状态: 断路器打开一段时间(可配置)后, 自动切换到半开状态

### 使用
| 属性 | 说明 | 默认值 |
| ---- | ---- | ---- |
| failureRateThreshold | 失败频率阈值  | 95 |
| waitDurationInOpenState | 打开状态等待时间, 由关闭状态自动变为半开状态的时间 | 60s |
| ringBufferSizeInHalfOpenState | 半开状态的环形缓冲区大小 | 10 |
| ringBufferSizeInOpenState | 关闭状态的环形缓存区大小 | 100 |
| include | 记录的异常类型 | |
| exclude | 不记录的异常类型 | |

**状态变换**  
close -> open: 关闭状态下, 如果环形缓冲区已满, 并且失败的频率>=95/100, 那么状态会变为打开状态  
open -> half-open: 打开状态下, 默认60s后状态自动变为half-open状态  
half-open -> open：半开状态下, 如果半开状态环形缓冲区已满, 失败频率>=95/100, 状态会变为打开状态  
half-open -> close: 半开状态下, 如果半开状态环形缓冲区已满, 并且失败频率<95/100, 状态会变为关闭状态

```java
public @interface CircuitBreaker {
	float failureRateThreshold() default 95;
	int waitDurationInOpenState() default 60;
	int ringBufferSizeInHalfOpenState() default 10;
	int ringBufferSizeInClosedState() default 100;
	Class<? extends Throwable>[] include();
	Class<? extends Throwable>[] exclude() default {};
}
```

## Mutex互斥
### 使用
`@Mutex`用于防止任务的并发执行. 常用于多个应用实例时的后台调度任务.

| 属性 | 说明 | 默认值 |
| ---- | ---- | ---- |
| key | 键值  | |
| scope | 作用域: 全局、应用级、本地 | Scope.GLOBAL |
```java
package org.ironrhino.core.throttle;

public @interface Mutex {
	String key() default "";
	Scope scope() default Scope.GLOBAL;
}
```
```java
package org.ironrhino.core.metadata;

public enum Scope implements Displayable {
	LOCAL, // only this jvm
	APPLICATION, // all jvm for this application
	GLOBAL; // all jvm for all application

	@Override
	public String toString() {
		return getDisplayName();
	}
}
```
### 实现
借助于`Redis`分布式锁, 获取锁成功则正常执行任务, 获取锁失败则抛`LockFailedException`锁失败异常.
```java
// MutexAspect.java
switch (mutex.scope()) {
case GLOBAL:
	break;
case APPLICATION:
	sb.append('-').append(AppInfo.getAppName());
	break;
case LOCAL:
	sb.append('-').append(AppInfo.getAppName()).append('-').append(AppInfo.getHostName());
	break;
default:
	break;
}
String lockName = sb.toString();
if (lockService.tryLock(lockName)) {
	try {
		return jp.proceed();
	} finally {
		lockService.unlock(lockName);
	}
} else {
	throw new LockFailedException(buildKey(jp));
}
```