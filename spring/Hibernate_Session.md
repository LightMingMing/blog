# Hibernate Session

前段时间生产一个后台调度任务(读取很多个用户的信息, 满足条件则发送短信)出现了内存溢出问题. 

从pinpoint观察, 当天应用内存逐渐升高, 发生几次FGC, 但内存仍然没有释放. 经过分析内存dump, 初步确定是因为Hibernate Sesison缓存没有释放而导致的. 

不过分析应用代码, 程序不存在明显的问题(如把所有数据全都读入内存的低级错误), 并且每个用户信息的查询都是在一个小事务中进行的, 为什么对象没有被GC回收呢? 甚是奇怪

## Session生命周期

初步看了下`sessionFactory.getCurrentSession()`的代码, 发现session是和当前线程绑定的(ThreadLocal).
```java
package org.springframework.transaction.support;

public abstract class TransactionSynchronizationManager {
	private static final ThreadLocal<Map<Object, Object>> resources =
			new NamedThreadLocal<>("Transactional resources");
}
```
那如果一些异步任务(线程池)或tomcat线程池, 线程复用时, 会不会使用同一个Session? 这样的话, 如果进行了很多次查询, 是不是会导致Session Cache不断增加, 而导致内存溢出呢?

首先验证tomcat线程复用时, 会不会使用同一个Session

程序如下
```java
@Repository
public class SessionRepository {

	protected final SessionFactory sessionFactory;

	public SessionRepository(SessionFactory sessionFactory) {
		this.sessionFactory = sessionFactory;
	}

	public String getCurrentSession() {
		return sessionFactory.getCurrentSession().toString();
	}
}
```

```java
@RestController
@RequestMapping("/session")
public class SessionController {

	@GetMapping("/getCurrentSession")
	public String getCurrentSession() {
        String session = sessionRepository.getCurrentSession()
        logger.info(Thread.currentThread().getName() + ", " +  session);
		return session;
	}
}
```

从结果来看, Session不会随着线程的复用而复用

```log
http-nio-8080-exec-8, SessionImpl(895281964<open>)
http-nio-8080-exec-2, SessionImpl(1502206300<open>)
http-nio-8080-exec-3, SessionImpl(105997204<open>)
http-nio-8080-exec-5, SessionImpl(222565365<open>)
http-nio-8080-exec-7, SessionImpl(1288319137<open>)
http-nio-8080-exec-9, SessionImpl(702967930<open>)
http-nio-8080-exec-10, SessionImpl(2142628415<open>)
http-nio-8080-exec-1, SessionImpl(1768578282<open>)
http-nio-8080-exec-4, SessionImpl(556567782<open>)
http-nio-8080-exec-6, SessionImpl(158987368<open>)

http-nio-8080-exec-8, SessionImpl(1884063516<open>)
http-nio-8080-exec-2, SessionImpl(1117799301<open>)
http-nio-8080-exec-3, SessionImpl(1720220016<open>)
http-nio-8080-exec-5, SessionImpl(861161998<open>)
http-nio-8080-exec-7, SessionImpl(285297757<open>)
http-nio-8080-exec-9, SessionImpl(658454829<open>)
http-nio-8080-exec-10, SessionImpl(1421535478<open>)
```

那么Session是在什么时候创建和关闭的呢?

通过debug, 发现Spring中`OpenSessionInViewFilter`会在每次请求执行前创建Session, 执行后关闭Session. 这就解释通上面现象了. 

```java
package org.springframework.orm.hibernate5.support;

public class OpenSessionInViewFilter extends OncePerRequestFilter {
	@Override
	protected void doFilterInternal(
			HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
			throws ServletException, IOException {
        
            // ...
        	SessionFactory sessionFactory = lookupSessionFactory(request);

            // ...
            Session session = openSession(sessionFactory);
            SessionHolder sessionHolder = new SessionHolder(session);
            TransactionSynchronizationManager.bindResource(sessionFactory, sessionHolder);

            // ...
			filterChain.doFilter(request, response);

            // ...
            SessionHolder sessionHolder = (SessionHolder) TransactionSynchronizationManager.unbindResource(sessionFactory);
            SessionFactoryUtils.closeSession(sessionHolder.getSession());
    }
}
```


> 结论: 使用`OpenSessionInViewFilter`的话, 每个请求处理前会创建Session, 处理后会关闭Session. 不会因为线程复用而导致Session Cache累积.

接下来, 就是使用了线程池的异步任务或者后台调度任务了, 这些任务不是Http请求, Session是什么时候创建和关闭的呢? 

上面`sessionRepository.getCurrentSession()`方法如果直接在一个异步任务中直接调用的会抛异常的, 因为当前不存在事务

```java
executor.execute(sessionRepository::getCurrentSession);
```

```java
package org.springframework.orm.hibernate5;

public class SpringSessionContext implements CurrentSessionContext {
    public Session currentSession() throws HibernateException {
        // ....
        else {
			throw new HibernateException("Could not obtain transaction-synchronized Session for current thread");
		}
    }
}
```

接下来, 就要从源码中寻找答案了

1. 当前没有事务时, 事务传播行为`REQUIRED`或`REQUIRES_NEW`或`NESTED`时, 则会创建一个新的事务, 如果当前没有Session, 则会创建新的Session
2. 当前有事务时
	1. `NEVER`抛异常
	2. `NOT_SUPPORTED`挂起当前事务
	3. `REQUIRES_NEW`挂起当前事务并且新建事务, 同时也会新建Session
	4. `NESTED`则创建一个保存点(Savepoint), 不新建事务也不新建Session

**如果Session是在当前事务创建的(newSession), 则当前事务完成时, Session则会被关闭**, 比如上面`OpenSessionInViewFilter`创建的Session, 则不会被事务管理器关闭.

```java
package org.springframework.transaction.support;

public abstract class AbstractPlatformTransactionManager implements PlatformTransactionManager, Serializable {

    // 
    @Overrdie
    public final TransactionStatus getTransaction(@Nullable TransactionDefinition definition)
                throws TransactionException {
        // ...

        if (isExistingTransaction(transaction)) {
			// Existing transaction found -> check propagation behavior to find out how to behave.
			return handleExistingTransaction(def, transaction, debugEnabled);
		}

        // ...
        else if (def.getPropagationBehavior() == TransactionDefinition.PROPAGATION_REQUIRED ||
				def.getPropagationBehavior() == TransactionDefinition.PROPAGATION_REQUIRES_NEW ||
				def.getPropagationBehavior() == TransactionDefinition.PROPAGATION_NESTED) {
			SuspendedResourcesHolder suspendedResources = suspend(null);
			if (debugEnabled) {
				logger.debug("Creating new transaction with name [" + def.getName() + "]: " + def);
			}
			try {
				boolean newSynchronization = (getTransactionSynchronization() != SYNCHRONIZATION_NEVER);
				DefaultTransactionStatus status = newTransactionStatus(
						def, transaction, true, newSynchronization, debugEnabled, suspendedResources);
				doBegin(transaction, def);
				prepareSynchronization(status, def);
				return status;
			}
			catch (RuntimeException | Error ex) {
				resume(null, suspendedResources);
				throw ex;
			}
        }
        // ...
    }

    private TransactionStatus handleExistingTransaction(
            TransactionDefinition definition, Object transaction, boolean debugEnabled)
            throws TransactionException {
        
        // NEVER -> 跑异常

        // NOT_SUPPORTED -> 当前事务挂起
        suspend(transaction);

        // REQUIRES_NEW -> 当前事务挂起, 新建事务, 旧的事务资源保存在新的事务状态
        SuspendedResourcesHolder suspendedResources = suspend(transaction);
        try {
            boolean newSynchronization = (getTransactionSynchronization() != SYNCHRONIZATION_NEVER);
            DefaultTransactionStatus status = newTransactionStatus(
                    definition, transaction, true, newSynchronization, debugEnabled, suspendedResources);
            doBegin(transaction, definition);
            prepareSynchronization(status, definition);
            return status;
        }

        // NESTED -> 创建Savepoint, 不会新建事务
        if (useSavepointForNestedTransaction()) {
            // Create savepoint within existing Spring-managed transaction,
            // through the SavepointManager API implemented by TransactionStatus.
            // Usually uses JDBC 3.0 savepoints. Never activates Spring synchronization.
            DefaultTransactionStatus status =
                    prepareTransactionStatus(definition, transaction, false, false, debugEnabled, null);
            status.createAndHoldSavepoint();
            return status;
        }

        // 其它 -> 校验隔离级别、只读属性是否一致 当前事务

    }

    // 事务完成后, 进行清理
    private void cleanupAfterCompletion(DefaultTransactionStatus status) {
		status.setCompleted();
		if (status.isNewSynchronization()) {
			TransactionSynchronizationManager.clear();
		}
		if (status.isNewTransaction()) {
			doCleanupAfterCompletion(status.getTransaction());
		}
		if (status.getSuspendedResources() != null) {
			if (status.isDebug()) {
				logger.debug("Resuming suspended transaction after completion of inner transaction");
			}
			Object transaction = (status.hasTransaction() ? status.getTransaction() : null);
			resume(transaction, (SuspendedResourcesHolder) status.getSuspendedResources());
		}
	}

}
```

如下是Hibernate事务管理器, `doBegin`方法, 会在当前没有Session时或者当前Session已于某个事务同步时, 新建一个Session, 并与当前事务同步(一个标记). 并且新建的Session, 会在当前的事务完成时, 而关闭, 见`doCleanupAfterCompletion`方法.
```java
package org.springframework.orm.hibernate5;

public class HibernateTransactionManager extends AbstractPlatformTransactionManager
		implements ResourceTransactionManager, BeanFactoryAware, InitializingBean {

    @Override
    protected void doBegin(Object transaction, TransactionDefinition definition) {
        // ...
		Session session = null;
		try {
			if (!txObject.hasSessionHolder() || txObject.getSessionHolder().isSynchronizedWithTransaction()) {
				Interceptor entityInterceptor = getEntityInterceptor();
				Session newSession = (entityInterceptor != null ?
						obtainSessionFactory().withOptions().interceptor(entityInterceptor).openSession() :
						obtainSessionFactory().openSession());
				if (logger.isDebugEnabled()) {
					logger.debug("Opened new Session [" + newSession + "] for Hibernate transaction");
				}
				txObject.setSession(newSession);
			}

            session = txObject.getSessionHolder().getSession();
            // ...

            // Bind the session holder to the thread.
			if (txObject.isNewSessionHolder()) {
				TransactionSynchronizationManager.bindResource(obtainSessionFactory(), txObject.getSessionHolder());
			}
			txObject.getSessionHolder().setSynchronizedWithTransaction(true);
        }
        // ...
    }

    // 事务挂起
    @Override
	protected Object doSuspend(Object transaction) {
		HibernateTransactionObject txObject = (HibernateTransactionObject) transaction;
		txObject.setSessionHolder(null);
		SessionHolder sessionHolder =
				(SessionHolder) TransactionSynchronizationManager.unbindResource(obtainSessionFactory());
		txObject.setConnectionHolder(null);
		ConnectionHolder connectionHolder = null;
		if (getDataSource() != null) {
			connectionHolder = (ConnectionHolder) TransactionSynchronizationManager.unbindResource(getDataSource());
		}
		return new SuspendedResourcesHolder(sessionHolder, connectionHolder);
	}


    @Overrride
    protected void doCleanupAfterCompletion(Object transaction) {

        // Remove the session holder from the thread.
		if (txObject.isNewSessionHolder()) {
			TransactionSynchronizationManager.unbindResource(obtainSessionFactory());
		}

        // ...

		if (txObject.isNewSession()) {
			if (logger.isDebugEnabled()) {
				logger.debug("Closing Hibernate Session [" + session + "] after transaction");
			}
			SessionFactoryUtils.closeSession(session);
		}
	}

}
```

## Session Cache

Session Cache一直了解的不多, 之前一直认为, 在一个事务中, 同一个主键, 进行多次查询的话, 只会从数据库查询一次. 不过后来发现, 即使不是同一个事务, 对同一个主键进行多次查询的话, 也只会从数据库查询一次. 

```java
@RestController
@RequestMapping("/session")
public class SessionController {

	@GetMapping("/dataSharingInEntireSession")
	public boolean dataSharingInEntireSession(@RequestParam("id") Long id) {
        // 不是在同一个事务中进行, 每次查询都是一个只读事务
    	User user1 = userRepository.get(id); // 事务1
		User user2 = userRepository.get(id); // 事务2
		return user1 == user2; // true
	}

}
```

Session缓存机制, 有时间再深入了解吧! 暂时先到这里

## 内存溢出真正原因

经过以上分析, 即使后台任务读取了大量用户的信息, 但由于每个用户信息的查询都是在一个小事务中进行中, 每次事务完成, 相应的session也会关闭(缓存的对象也会被清理), **是不会导致内存溢出的**.

之后想到, 当天后台任务并不是系统调度发起, 而是开发在程序中写了个后门(在浏览器中, 执行相关脚本, 调用Spring Bean的方法) 从浏览器中发起的, 这无形中放大了session的生命周期, 导致Session Cache不断增加, 最终内存溢出.