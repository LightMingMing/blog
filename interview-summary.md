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

### Spring

> spring boot 怎么自定义 starter

原理：
@SpringBootAppliction 注解带有 @EnableAutoConfiguration;
@EnableAutoConfiguration 通过 @Import 会向容器中注册 AutoConfigurationImportSelector, 该类的作用就是从jar包中的 `META-INF/spring.factories` 文件里寻找EnableAutoConfiguration类，并将这些类注册到容器里;

```java
@SpringBootConfiguration
@EnableAutoConfiguration
@ComponentScan(excludeFilters = { @Filter(type = FilterType.CUSTOM, classes = TypeExcludeFilter.class),
		@Filter(type = FilterType.CUSTOM, classes = AutoConfigurationExcludeFilter.class) })
public @interface SpringBootApplication {
    // ...
}

@AutoConfigurationPackage
@Import(AutoConfigurationImportSelector.class)
public @interface EnableAutoConfiguration {
    // ...
}
```

如 mybatis
```
# Auto Configure
org.springframework.boot.autoconfigure.EnableAutoConfiguration=\
org.mybatis.spring.boot.autoconfigure.MybatisLanguageDriverAutoConfiguration,\
org.mybatis.spring.boot.autoconfigure.MybatisAutoConfiguration
```

自定义xxx-starter：
1. xxx-starter 包负责管理依赖, 比如依赖 xxx-autoconfigure 包;
2. xxx-autoconfigure 包下, 增加 META-INF/spring.factories 文件, 并在该文件下配置 EnableAutoConfiguration 对应的配置类, 配置类实现 starter 相关 bean 的配置(包括xxxProperties.java 指定配置以***开头)

如 mybatis
```
@ConfigurationProperties(prefix = MybatisProperties.MYBATIS_PREFIX)
public class MybatisProperties {
    public static final String MYBATIS_PREFIX = "mybatis";
    // ...
}

@org.springframework.context.annotation.Configuration
@ConditionalOnClass({ SqlSessionFactory.class, SqlSessionFactoryBean.class })
@ConditionalOnSingleCandidate(DataSource.class)
@EnableConfigurationProperties(MybatisProperties.class)
@AutoConfigureAfter({ DataSourceAutoConfiguration.class, MybatisLanguageDriverAutoConfiguration.class })
public class MybatisAutoConfiguration implements InitializingBean {
    // ...
}
```

使用: 
使用方只需要在 pom 文件添加 starter 依赖, 以及在 application.properties 中添加 starter 所需配置即可.

