# Java队列同步器及相关组件
> 拖的稍微有点久了, 是时候写一下了...
## Java队列同步器
### 概述
队列同步器指的是`AbstractQueuedSynchronizer`简称`AQS`, 顾名思义, 它是一个以队列的方式来进行多线程同步的基础组件. 在Java中, 它是一个抽象类, 子类可以有选择的实现以下方法, 来定制不同功能的同步器.
```java
protected boolean tryAcquire(int arg)
protected boolean tryRelease(int arg)
protected int tryAcquireShared(int arg)
protected boolean tryReleaseShared(int arg)
protected boolean isHeldExclusively()
```
我们平常较为常见的`ReentrantLock`(可重入锁)、`CountDownLatch`(倒计时栓、发令枪)、`Semaphore`(信号量)、`ReentrantReadWriteLock`(可重入读写锁)等(其实也就这些O(∩_∩)O)都是基于它实现的, 另外在[线程池`ThreadPoolExecutor`](ThreadPoolExecutor.md)中也有它的影子.
![AQS及相关组件](png/aqs_all_synchronizers.png)
这里我们先介绍`AQS`基本属性和同步队列, 之后再根据其各个组件深入分析.
### 基本属性
1. `exclusiveOwnerThread` 独占模式时的独占线程, 比如`ReentrantLock`以及`ReentrantReadWriteLock`中的`写锁`都是独占模式, 某个同步方法/块在同一时刻最多只能有一个线程能够访问. 
2. `state` 同步状态, 子类常常根据状态值, 来判断获取许可(`tryAcquire`或`tryAcquiredShared`)是否成功, 以及根据`compareAndSetState`CAS方法修改状态值来释放许可(`tryRelease`或`tryReleaseShared`)
```java
private volatile int state;

protected final int getState() {
    return state;
}

protected final void setState(int newState) {
    state = newState;
}

protected final boolean compareAndSetState(int expect, int update) {
    return unsafe.compareAndSwapInt(this, stateOffset, expect, update);
}
```
3. `head`和`tail` 队列的首尾节点, 初始时, 两个节点都为空(表示没有线程加入过等待队列)
```java
private transient volatile Node head;
private transient volatile Node tail;
```
### 同步队列
同步队列或者等待队列, 是一种**CLH**锁队列. 在Java AQS中, 它是一个双向队列, 除了头节点外, 每一个节点一般都会有一个等待线程, 并线程的控制信息(状态`status`)持有在节点的前驱节点中. 
> The wait queue is a variant of a "CLH" (Craig, Landin, and Hagersten) lock queue.
#### 等待节点
1. 节点类型  
    独占和共享, 用于表示节点的后置节点等待是一个独占锁还是共享锁. 一般同步器`ReentrantReadWriteLock`都只会采用一种模式除了, 独占模式(实现`tryAcquire`、`tryRelease`方法)或共享模式(实现`tryAcquireShared`、`tryReleaseShared`方法). 而在`ReentrantReadWriteLock`中, 独占节点则对应的是写锁, 共享节点则对应的是读锁.
    ```java
    static class Node {
        /** Marker to indicate a node is waiting in shared mode */
        static final Node SHARED = new Node();
        /** Marker to indicate a node is waiting in exclusive mode */
        static final Node EXCLUSIVE = null;

        Node nextWaiter;

        final boolean isShared() {
            return nextWaiter == SHARED;
        }
    }
    ```
2. 等待状态  
    **CANCELLED** 取消状态, 比如说等待线程被中断, 节点状态则会变为取消状态  
    **SIGNAL** 等待通知, 表示节点的后置节点的线程在park状态或不久就会被为park状态  
    **CONDITION** 条件等待, 当前节点在条件等待队列, `ReentrantLock`、`ReentrantReadWriteLock`  
    **PROPAGATE** 传播, 只有头节点会使用, 下一个`acquireShared`应该无条件传播?? **暂时不管**  
    ```java
    static class Node {
        /** waitStatus value to indicate thread has cancelled. */
        static final int CANCELLED =  1;
        /** waitStatus value to indicate successor's thread needs unparking. */
        static final int SIGNAL    = -1;
        /** waitStatus value to indicate thread is waiting on condition. */
        static final int CONDITION = -2;
        /**
            * waitStatus value to indicate the next acquireShared should
            * unconditionally propagate.
            */
        static final int PROPAGATE = -3;

        volatile int waitStatus;
    }
    ```
#### 相关方法
> 这里参考的Java 11版本的代码, 和Java 8会有些区别
1. 入队  
    队列初始状态, `head` = `tail` = null, 因此`tail`为`null`, 需要对队列进行初始化. 同时入队操作采用CAS修改尾部节点的方式来保证线程安全.
    ```java
    private Node enq(Node node) {
        for (;;) {
            Node oldTail = tail;
            if (oldTail != null) {
                node.setPrevRelaxed(oldTail);
                if (compareAndSetTail(oldTail, node)) {
                    oldTail.next = node;
                    return oldTail;
                }
            } else {
                initializeSyncQueue();
            }
        }
    }

    private Node addWaiter(Node mode) {
        Node node = new Node(mode);

        for (;;) {
            Node oldTail = tail;
            if (oldTail != null) {
                node.setPrevRelaxed(oldTail);
                if (compareAndSetTail(oldTail, node)) {
                    oldTail.next = node;
                    return node;
                }
            } else {
                initializeSyncQueue();
            }
        }
    }
    ```
2. CAS修改尾部节点  
    Java11中, 借助于VarHandle(Java 9中引入)实现
    ```java
    // @version 11
    private static final VarHandle TAIL;

    static {
        try {
            MethodHandles.Lookup l = MethodHandles.lookup();
            TAIL = l.findVarHandle(AbstractQueuedSynchronizer.class, "tail", Node.class);
        } catch (ReflectiveOperationException e) {
            throw new ExceptionInInitializerError(e);
    }

    private final boolean compareAndSetTail(Node expect, Node update) {
        return TAIL.compareAndSet(this, expect, update);
    }
    ```
    Java8中, 借助于Unsafe实现, 通过计算出`tail`在`AbstractQueuedSynchronizer`对象中的偏移地址, 通过CAS修改该地址处数据.  
    我们如果需要原子修改引用对象的话, 1.8版本可以借助于`AtomicReferenceFieldUpdater`来实现, 原理和这里类似. 如果Java版本为1.9以上版本时, 可以参考使用`VarHandle`. 至于性能, **TODO 以后可以做个测试**
    ```java
    // @version 1.8
    private static final Unsafe unsafe = Unsafe.getUnsafe();
    private static final long tailOffset;

    static {
        try {
            tailOffset = unsafe.objectFieldOffset
                (AbstractQueuedSynchronizer.class.getDeclaredField("tail"));
        } catch (Exception ex) { throw new Error(ex); }
    }

    private final boolean compareAndSetTail(Node expect, Node update) {
        return unsafe.compareAndSwapObject(this, tailOffset, expect, update);
    }
    ```
3. 队列初始化, 同样采用CAS操作保证并发初始化只有一次会成功 
    ```java
    /**
     * Initializes head and tail fields on first contention.
     */
    private final void initializeSyncQueue() {
        Node h;
        if (HEAD.compareAndSet(this, null, (h = new Node())))
            tail = h;
    }
    ```

至此, 基础部分介绍的差不多了, 接下来, 我们从以下同步器的实现来对ASQ进行进行深入分析.

## ReentrantLock
### Lock接口
在讲解`ReentrantLock`之前, 先看看`Lock`接口都有哪些方法
```java
package java.util.concurrent.locks;

public interface Lock {
    // 阻塞直至获取锁
    void lock();
    // 阻塞直至获取锁或者被中断
    void lockInterruptibly() throws InterruptedException;
    // 尝试获取锁, 不会阻塞
    boolean tryLock();
    // 限时获取锁, 可被中断
    boolean tryLock(long time, TimeUnit unit) throws InterruptedException;
    // 释放锁
    void unlock();
    // 创建新条件对象
    Condition newCondition();
}
```
因此`ReentrantLock`与`Synchronized`相比, 一个明显的优点就是更加灵活, 支持可中断获取锁、非阻塞获取锁、限时获取锁.
### 公平锁与非公平锁
`ReentrantLock`默认无参构造函数`new ReentrantLock()`创建的是非公平锁, 也可以使用`new ReentrantLock(boolean fair)`来指明使用公平锁或非公平锁  
```java
public ReentrantLock() {
    sync = new NonfairSync();
}
public ReentrantLock(boolean fair) {
    sync = fair ? new FairSync() : new NonfairSync();
}
```
**公平锁**: 如果当前队列中存在等待线程, 新的获取锁线程会加入到等待队列进行排队
**非公平锁**: 如果此时锁未被占用(比方刚刚释放), 则新的线程有机会获取锁而不用排队    

两者相比, 非公平锁有着更高的吞吐量, 原因在于, 无论公平锁还是非公平锁在锁释放时, 都会唤醒队列中第一个等待线程, 也就是执行`Lock.unpark(waitThread)`操作, 而此操作开销较大, 耗时较长, 采用非公平锁, 新请求先获取锁, 执行完临界区代码后, 又迅速释放锁(快入快出), 而此时等待节点中线程由刚好唤醒, 获取锁后, 节点从队列中移出. 因此在并发量较大的时候, 非公平锁会有较高的吞吐量.

### lock方法
`lock()` 阻塞获取锁: 获取锁成功, 则当前线程继续执行; 获取锁失败, 当前线程加入到等待队列  
如下是`lock`方法实现, `sync`指的是AQS的实现(公平同步器或非公平同步器). 前面提到过, 前缀为`try`的方法是需要子类实现, 因此`acquire(1)`这个方法是在AQS里实现的.
```java
// ReentrantLock.java
public void lock() {
    sync.acquire(1); 
}
```
#### acquire
调用子类`tryAcquire`实现. 可以看出如果返回`true`, 则当前方法执行完毕; 返回`false`, 则会向队列中加入一个`独占`模式的等待节点.
```java
// AQS.java
public final void acquire(int arg) {
    if (!tryAcquire(arg) &&
        acquireQueued(addWaiter(Node.EXCLUSIVE), arg))
        selfInterrupt();
}
```
#### tryAcquire
**公平锁实现**  
`state`初始值为0, 表示当前许可可被获取.   
该方法在以下情况时, 会返回`true`(表示获取锁或许可成功)
1. `state`为0, 并且**队列中没有等待线程**, CAS修改`state`成功后, 设置独占线程, 返回true
2. `state`不为0, 但当前线程是独占线程, 对`state`进行累计, 并返回true
```java
// FairSync.java
protected final boolean tryAcquire(int acquires) {
    final Thread current = Thread.currentThread();
    int c = getState();
    if (c == 0) {
        if (!hasQueuedPredecessors() &&
            compareAndSetState(0, acquires)) {
            setExclusiveOwnerThread(current);
            return true;
        }
    }
    else if (current == getExclusiveOwnerThread()) {
        int nextc = c + acquires;
        if (nextc < 0)
            throw new Error("Maximum lock count exceeded");
        setState(nextc);
        return true;
    }
    return false;
}
```
**非公平锁实现**  
这里一个很明显的区别就是, 它不会管队列中有没有等待线程. 只要当前锁可被获取, 在CAS修改`state`成功后, 则设置独占线程.
```java
// NoFairSync.java
protected final boolean tryAcquire(int acquires) {
    return nonfairTryAcquire(acquires);
}

// Sync.java
final boolean nonfairTryAcquire(int acquires) {
    final Thread current = Thread.currentThread();
    int c = getState();
    if (c == 0) {
        if (compareAndSetState(0, acquires)) {
            setExclusiveOwnerThread(current);
            return true;
        }
    }
    else if (current == getExclusiveOwnerThread()) {
        int nextc = c + acquires;
        if (nextc < 0) // overflow
            throw new Error("Maximum lock count exceeded");
        setState(nextc);
        return true;
    }
    return false;
}
```

### unlock方法
结合lock方法, 大概可以猜测出unlock会执行以下动作:
1. 独占线程置为null(非重入锁)
2. 修改状态值`state`
3. 唤醒头节点后置节点的等待线程(非重入锁)
```java
// ReentrantLock.java
public void unlock() {
    sync.release(1);
}
```
#### release
调用子类`tryRelease(arg)`尝试释放许可方法, 如果释放许可成功即返回true, 会调用unparkSuccessor方法, 唤醒头节点后置节点的等待线程.
```java
// AQS.java
public final boolean release(int arg) {
    if (tryRelease(arg)) {
        Node h = head;
        if (h != null && h.waitStatus != 0)
            unparkSuccessor(h); // 3
        return true;
    }
    return false;
}
```
#### tryRelease
当前状态值减去要释放的许可数量后为0时, 锁才能释放, 返回true;
```java
// Sync.java
protected final boolean tryRelease(int releases) {
    int c = getState() - releases;
    if (Thread.currentThread() != getExclusiveOwnerThread())
        throw new IllegalMonitorStateException();
    boolean free = false;
    if (c == 0) {
        free = true;
        setExclusiveOwnerThread(null); // 1
    }
    setState(c); // 2
    return free;
}
```

### tryLock方法
tryLock方法: 获取锁成功时, 返回true; 获取锁失败时, 返回false, 但是当前线程不会加入等待队列中阻塞;
这里使用的`nonfaireTryAcquire`[非公平的尝试获取许可方法](#tryAcquire). 因此这里无论公平锁还是非公平锁, `tryLock`都是采用非公平的方式
```java
// ReentrantLock.java
public boolean tryLock() {
    return sync.nonfairTryAcquire(1);
}
```

### lockInterruptibly方法
lockInterruptibly方法能够响应中断, 其实现于`lock()`方法, 比较类似, 区别就是线程被唤醒时, 它会检测线程的中断状态, 如果有中断标记, 会抛`InterruptedException`异常
```java
// AQS.java
private void doAcquireInterruptibly(int arg)
    throws InterruptedException {
    final Node node = addWaiter(Node.EXCLUSIVE);
    try {
        for (;;) {
            final Node p = node.predecessor();
            if (p == head && tryAcquire(arg)) {
                setHead(node);
                p.next = null; // help GC
                return;
            }
            if (shouldParkAfterFailedAcquire(p, node) &&
                parkAndCheckInterrupt())
                throw new InterruptedException();
        }
    } catch (Throwable t) {
        cancelAcquire(node);
        throw t;
    }
}
```

### 条件
线程获取锁后, 有时可能需要等待某一资源,也就是条件等待`await()`, 这时它会先释放锁, 然后进入条件等待队列进行等待; 之后另外一个获取锁的线程在临界区内释放该资源后, 则会发送通知`signal()/signalAll()`, 它会将条件等待队列中头节点或所有节点加入到**AQS**的等待队列中, 等待锁的释放.  

如下是`Condition`接口相关方法:
```java
public interface Condition {
    void await() throws InterruptedException; // 条件等待, 可中断
    void awaitUninterruptibly(); // 不可中断的条件实现
    long awaitNanos(long nanosTimeout) throws InterruptedException; // 限时条件等待, 线程不会加入条件等待队列
    boolean await(long time, TimeUnit unit) throws InterruptedException; // 限时等待, 线程不会加入条件等待队列
    boolean awaitUntil(Date deadline) throws InterruptedException; // 限时等待, 线程不会加入条件等待队列
    void signal(); // 通知
    void signalAll(); // 通知
}
```
在AQS的条件队列采用的也是一个双向链式队列
> 注: 每一个条件对象都会有一个条件队列
```java
// AQS.java
public class ConditionObject implements Condition, java.io.Serializable {
    /** First node of condition queue. */
    private transient Node firstWaiter;
    /** Last node of condition queue. */
    private transient Node lastWaiter;
}
```
#### addConditionWaiter
添加条件等待节点, 从这里可知只有独占模式的独占线程才能够进行条件等待
```java
// ConditionObject.java
private Node addConditionWaiter() {
    if (!isHeldExclusively())
        throw new IllegalMonitorStateException();
    Node t = lastWaiter;
    // If lastWaiter is cancelled, clean out.
    if (t != null && t.waitStatus != Node.CONDITION) {
        unlinkCancelledWaiters();
        t = lastWaiter;
    }

    Node node = new Node(Node.CONDITION);

    if (t == null)
        firstWaiter = node;
    else
        t.nextWaiter = node;
    lastWaiter = node;
    return node;
}
```
#### await方法
1. 线程加入条件等待队列
2. 释放锁
3. 线程阻塞, 等待通知或者被中断, 无论是通知还是被中断, 条件节点都会被转移到AQS的等待队列
4. 等待获取锁
```java
// ConditionObject.java
public final void await() throws InterruptedException {
    if (Thread.interrupted())
        throw new InterruptedException();
    Node node = addConditionWaiter();
    int savedState = fullyRelease(node);
    int interruptMode = 0;
    while (!isOnSyncQueue(node)) {
        LockSupport.park(this);
        if ((interruptMode = checkInterruptWhileWaiting(node)) != 0)
            break;
    }
    if (acquireQueued(node, savedState) && interruptMode != THROW_IE) 
        interruptMode = REINTERRUPT;
    if (node.nextWaiter != null) // clean up if cancelled
        unlinkCancelledWaiters();
    if (interruptMode != 0)
        reportInterruptAfterWait(interruptMode);
}
```
条件等待线程被中断后进入AQS等待队, 之后等线程获取锁后, 重新抛中断异常
```java
// ConditionObject.java
private int checkInterruptWhileWaiting(Node node) {
    return Thread.interrupted() ?
        (transferAfterCancelledWait(node) ? THROW_IE : REINTERRUPT) :
        0;
}

// AQS.java
final boolean transferAfterCancelledWait(Node node) {
    if (node.compareAndSetWaitStatus(Node.CONDITION, 0)) {
        enq(node);
        return true;
    }
    while (!isOnSyncQueue(node))
        Thread.yield();
    return false;
}

// ConditionObject.java
private void reportInterruptAfterWait(int interruptMode)
    throws InterruptedException {
    if (interruptMode == THROW_IE)
        throw new InterruptedException();
    else if (interruptMode == REINTERRUPT)
        selfInterrupt();
}
```
#### awaitUninterruptibly方法
不可中断的条件等待实现比较简单  
1. 线程加入条件等待队列
2. 释放锁
3. 等待通知
4. 等待获取锁
```java
// ConditonObject.java
public final void awaitUninterruptibly() {
    Node node = addConditionWaiter();
    int savedState = fullyRelease(node);
    boolean interrupted = false;
    while (!isOnSyncQueue(node)) {
        LockSupport.park(this);
        if (Thread.interrupted())
            interrupted = true;
    }
    if (acquireQueued(node, savedState) || interrupted)
        selfInterrupt();
}
```
#### signal方法
将条件等待队列的头节点转移到等待队列, 并将条件等待线程唤醒
```java
// ConditionObject.java
public final void signal() {
    if (!isHeldExclusively())
        throw new IllegalMonitorStateException();
    Node first = firstWaiter;
    if (first != null)
        doSignal(first);
}

private void doSignal(Node first) {
    do {
        if ( (firstWaiter = first.nextWaiter) == null)
            lastWaiter = null;
        first.nextWaiter = null;
    } while (!transferForSignal(first) &&
                (first = firstWaiter) != null);
}

final boolean transferForSignal(Node node) {
    if (!node.compareAndSetWaitStatus(Node.CONDITION, 0))
        return false;
    Node p = enq(node);
    int ws = p.waitStatus;
    if (ws > 0 || !p.compareAndSetWaitStatus(ws, Node.SIGNAL))
        LockSupport.unpark(node.thread);
    return true;
}
```
#### signalAll方法
signalAll则是将条件等待队列所有节点转移到AQS的锁等待队列中, 并且唤醒条件等待线程
```java
//ConditionObject.java
private void doSignalAll(Node first) {
    lastWaiter = firstWaiter = null;
    do {
        Node next = first.nextWaiter;
        first.nextWaiter = null;
        transferForSignal(first);
        first = next;
    } while (first != null);
}
```

## CountDownLatch

## Semaphore

## ReentrantReadWriteLock