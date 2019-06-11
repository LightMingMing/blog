# Java任务调度

## 概述
`ScheduledThreadPoolExecutor`是一种特殊的线程池(`ThreadPoolExecutor`), 可以**延迟**执行任务, 或者**周期**性的执行任务.

在`ScheduledExecutorService`接口中定义了3种调度方式
```java
package java.util.concurrent;

public interface ScheduledExecutorService extends ExecutorService {
    // 延迟执行任务
    public ScheduledFuture<?> schedule(Runnable command, long delay, TimeUnit unit);
    
    // 延迟执行任务
    public <V> ScheduledFuture<V> schedule(Callable<V> callable, long delay, TimeUnit unit);

    // 周期性执行 固定周期
    public ScheduledFuture<?> scheduleAtFixedRate(Runnable command, long initialDelay,
                                                 long period, TimeUnit unit);
    // 周期性执行 固定延迟
    public ScheduledFuture<?> scheduleWithFixedDelay(Runnable command, long initialDelay,
                                                 long delay, TimeUnit unit);
}
```

## 延迟工作队列

### 延迟执行任务

### 固定周期执行

### 固定延迟执行

## Spring任务调度实现