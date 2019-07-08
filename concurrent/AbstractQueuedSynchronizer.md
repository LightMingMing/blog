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
#### 节点

#### 相关方法

## ReentrantLock

## CountDownLatch

## Semaphore

## ReentrantReadWriteLock