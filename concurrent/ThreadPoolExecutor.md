# 深入学习Java线程池及源码分析

## 核心参数
`ThreadPoolExecutor`线程池构造函数如下:
```java
public ThreadPoolExecutor(int corePoolSize,
                          int maximumPoolSize,
                          long keepAliveTime,
                          TimeUnit unit,
                          BlockingQueue<Runnable> workQueue,
                          ThreadFactory threadFactory,
                          RejectedExecutionHandler handler)
```
### corePoolSize
corePoolSize 线程池核心大小、基本大小. 当线程池中线程大小小于corePoolSize时, 线程池会每一个新来的任务都创建一个工作线程. 如下图所示:
![corePoolSize](png/tpe_corePoolSize.png)

### workQueue
workQueue 任务队列. 当线程池中线程大小达到corePoolSize时, 新来的任务被放入到工作队列中, 等待空闲下来的工作线程去执行. 如下图所示:
![workQueue](png/tpe_workQueue.png)
workQueu是一个阻塞队列, 在线程池中常用的实现有: `LinkedBlockingQueue`、`ArrayBlockingQueue`、`PriorityBlockingQueue`、`SynchronousQueue`.

### maximunPoolSize
maimumPoolSize 线程池最大线程数量, 最大活动线程数量, 能同时活动的线程上限. 当工作队列满的时候, 才会创建超出corePoolSize但不会对于maximumPoolSize大小的线程. 如下图所示:
![maximunPoolSize](png/tpe_maximumPoolSize.png)

### keepAliveTime && unit
keepAliveTime && unit 线程空闲时间. 超出核心线程数量之外的线程, 如果发生空闲(工作队列为空, 没活干)并且空闲时间达到keepAliveTime时(是时候开除你了), 线程会退出.

### rejectedExecutionHandler
rejectedExecutionHandler 线程的拒绝策略、饱和策略, 即当工作队列填满并且活动线程数量为最大时, 饱和策略则开始生效.
![reject](png/tpe_reject.png)
如下为RejectedExecutionHandler接口
```java
package java.util.concurrent;
public interface RejectedExecutionHandler {
   void rejectedExecution(Runnable r, ThreadPoolExecutor executor);
}
```
线程池有四种饱和策略
1. AbortPolicy 中止策略, 线程池默认的饱和策略, 在任务被拒绝时, 抛`RejectedExecutionException`异常
```java
public void rejectedExecution(Runnable r, ThreadPoolExecutor e) {
    throw new RejectedExecutionException("Task " + r.toString() +
                                         " rejected from " +
                                         e.toString());
}
```
2. DiscardPolicy 抛弃策略, 悄悄的抛弃任务, 不抛异常
```java
// does nothing
public void rejectedExecution(Runnable r, ThreadPoolExecutor e) {
}
```
3. DiscardOldestPolicy 抛弃下一个将被执行的任务, 通俗来说, 也就是最早的任务, 然后尝试重新提交新的任务
```java
public void rejectedExecution(Runnable r, ThreadPoolExecutor e) {
    if (!e.isShutdown()) {
        e.getQueue().poll();
        e.execute(r);
    }
}
```
> 如果队列为优先级队列, 则会移除优先级最高的任务, 因此不要将优先级队列和抛弃最旧饱和策略一起使用
4. CallerRunsPolicy 调用者执行策略, 即线程池不会执行任务, 而是由调用线程(主线程)去执行
```java
public void rejectedExecution(Runnable r, ThreadPoolExecutor e) {
    if (!e.isShutdown()) {
        r.run();
    }
}
```
虽说名字听起来有点高大上, 但是从代码上看起来还是很容易理解的

## Executors介绍
熟悉线程池几个核心的参数后, 现在来看Executors以下几个创建线程池的方法, 会更容易理解.
### newFixedThreadPool 固定大小的线程池
```java
public static ExecutorService newFixedThreadPool(int nThreads) {
    return new ThreadPoolExecutor(nThreads, nThreads,
                                  0L, TimeUnit.MILLISECONDS,
                                  new LinkedBlockingQueue<Runnable>());
```
newFixedThreadPool 核心线程数量等于最大线程数量, 最大空闲时间为0, 线程不会空闲退出. `LinkedBlockingQueue`无参构造函数, 默认队列大小为`Integer.MAX_VALUE`, 因此newFixedThreadPool在任务的处理速度小于任务请求的速率, 那么队列中的任务可能会无限制的增加, 降低系统的吞吐量.
```java
public LinkedBlockingQueue() {
    this(Integer.MAX_VALUE);
}
```
### newCachedThreadPool 可缓存的线程池
```java
public static ExecutorService newCachedThreadPool() {
	return new ThreadPoolExecutor(0, Integer.MAX_VALUE,
    	                          60L, TimeUnit.SECONDS,
        	                      new SynchronousQueue<Runnable>());
```
newCachedThreadPool 核心线程数量为0, 最大线程数量为`Integer.MAX_VALUE`, 线程空闲时间为60s. 同样在任务到来速度如果大于任务处理速度时, 会带来如下问题:
1. 线程创建的开销本来就高, 延迟处理的请求
2. 大量线程频繁竞争CPU资源, 增加额外的性能开销
3. 线程也会大量占用系统资源如内存, 导致OOM
不过如果任务之间有依赖关系,使用newCacheThreadPool时, 不会发生死锁; 而使用有界线程池时, 则可能会导致线程饥饿死锁.
> `SynchronousQueue`用于避免任务排队, 能够将任务从生产者线程移交给工作着线程, 它不是一个真正的队列, 而是一种在线程之间进行移交的机制. <<Java并发编程实战>>

### newSingleThreadExecutor 单线程线程池
```java
public static ExecutorService newSingleThreadExecutor() {
    return new FinalizableDelegatedExecutorService
        (new ThreadPoolExecutor(1, 1,
                                0L, TimeUnit.MILLISECONDS,
                                new LinkedBlockingQueue<Runnable>()));
```

## 线程池状态
线程池有以下5个状态
1. RUNNING 能够接收新任务和处理队列中的任务
2. SHUTDOWN 线程池不接收新任务, 但是会处理队列中的任务
3. STOP 不接受新任务, 也不会处理队列中的任务, 并且会中断处理中的任务
4. TIDYING 所有的任务都已结束, 并且工作线程数量为0, 到该状态后, 会运行terminated()钩子方法
5. TERMINATED terminated()完成后
状态转化图如下:
![线程池状态](png/tpe_state.png)
