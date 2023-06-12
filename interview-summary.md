# 面试总结

## Java

### 并发

> juc 包下有哪些类 

1. 锁工具
    - Lock: ReentrantLock, ReentrantReadWriteLock
    - CountDownLatch, Semaphore, CyclicBarrier
    - LockSupport (park & unpark方法在 AQS 里有大量使用)
2. 并发集合
    - List: CopyOnWriteArrayList
    - 队列: ArrayBlockingQueue, LinkedBlockingQueue, ConcurrentLinkedQueue, DelayQueue 延迟队列, PriorityBlockingQueue 优先级队列
    - Map: ConcurrentHashMap
3. 原子操作工具
    - AtomicBoolean, AtomicInteger, AtomicLong, AtomicReference
    - AtomicIntegerFieldUpdater,AtomicLongFieldUpdater, AtomicReferenceFieldUpdater
4. 并发执行工具
    - 线程池、调度池、ForkJoinPool
    - 基础类: Runnable, Callable, Future, FutureTask, CompletableFuture (JDK 8)
