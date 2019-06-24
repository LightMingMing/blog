# 摘要

## 铁犀牛

* [x] [微服务-服务消费方实现](/ironrhino/remoting-consumer.md)  
* [x] [微服务-服务发布方实现](/ironrhino/remoting-provider.md)  
* [x] [单点登录](/ironrhino/single-sign-on.md)  
* [x] [两经纬度间距离公式推导](/ironrhino/distance-formula-of-two-coordinates.md)  
* [ ] [流量控制](/ironrhino/throttle.md)
    * 并发量控制 `@Bulkhead`、`@Concurrency`
    * 频率控制 `@Frequency`、`@RateLimiter`
    * 断路器 `@CircuitBreaker`
    * 互斥 `@Mutex`

## Java并发

* [x] [深入学习Java线程池及源码分析](/concurrent/ThreadPoolExecutor.md)  
* [ ] [Java任务调度](/concurrent/ScheduledThreadPoolExecutor.md)  
    * 延时执行、周期执行是如何实现的
    * Spring中任务调度是如何实现的
* [ ] [Java队列同步器](/concurrent/AbstractQueuedSynchronizer.md)  
    * `ReentranLock`、`ReentrantReadWriteLock`、`CountDownLatch`、`Semaphore`、 `ThreadPoolExecutor`
    * ReentrantLock中, 调用`condition.await()`前必须先获得锁`lock()`, 并且`await()`操作会释放锁, `await()`结束时(有其它线程执行`signal()`或`signalAll()`)重新获取锁, 然后继续后续操作, 关于这段逻辑是如何实现的?

## 其它
* [位操作](bit-operation.md) 