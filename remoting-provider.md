

# 微服务-服务发布方

[TOC]

## 上期回顾

上期讲述了铁犀牛微服务服务消费方的实现，我们知道了服务消费方能够像使用本地组件一样使用微服务接口(也就是`@Autowired`能够注入成功)，是因为有`HttpInvokerClient`这个的一个工厂bean(`FactoryBean`)，在消费方的容器启动时，会为每一个微服务接口创建这样的一个代理对象。

其中服务消费方的执行流程如下：

1. 微服务接口方法拦截
2. 将方法签名和方法参数值封装到`RemotingInvocation`中
3. 建立http请求连接, **序列化**`RemotingInvocation`到连接的输出流中，其中请求地址格式为 `http://ip:port/remoting/httpinvoker/${interaceName}`
4. 将响应的输出流中的数据**反序列化**为`RemotingInvocationResult`
5. 其中`RemotingInvocationResult`封装的便是远程调用的结果

据此，我们大致可以猜测出微服务的服务发布方的处理流程：

1. 从请求的的URL中获取微服务接口名，从容器中获取接口的具体实现
2. 将请求的输入流中的数据**反序列化**为`RemotingInvocation`
3. 根据`RemotingInvocation`所封装的方法签名和方法参数值，反射执行该方法
4. 将反射执行的结果封装到`RemotingInvocationResult`中
5. 最后**序列化**`RemotingInvocationResult`到响应的输出流中

那么接下来，我们就具体看看服务方是如何对请求进行处理的。

## 容器启动阶段

### Servlet注册

我们最初学习Servlet时，都是通过`web.xml`来给容器注册并配置`servlet`，而Spring框架提供了一个`WebApplicationInitializer`接口，允许我们以代码的方式来注册`servlet`，铁犀牛则利用该接口进行**去XML化**。

如下`RemotingServerInitializer`注册了一个的`InheritedDispatcherServlet`来处理请求地址为`/remoting/*`格式的请求。

```java
package org.ironrhino.core.remoting.server;

public class RemotingServerInitializer implements WebApplicationInitializer {

	@Override
	public void onStartup(ServletContext servletContext) throws ServletException {
		String servletName = HttpInvokerServer.class.getName();
    // 注册组件
		AnnotationConfigWebApplicationContext ctx = new AnnotationConfigWebApplicationContext();
		ctx.setId(servletName);
		ctx.register(RemotingServerConfiguration.class);
    // 注册Servlet
		ServletRegistration.Dynamic dynamic = servletContext.addServlet(servletName,
				new InheritedDispatcherServlet(ctx));
		dynamic.addMapping("/remoting/*");
		dynamic.setAsyncSupported(true);
		dynamic.setLoadOnStartup(Integer.MAX_VALUE - 1);
	}

}
```

`InheritedDispatcherServlet`继承了Spring MVC的`DispatcherServlet`，`DispatcherServlet`用于分发请求，也就是对url进行匹配，将不同url的请求分发给不同的请求处理器来处理，如我们比较熟悉的`Controller`本质上也是一个请求处理器。`InheritedDispatcherServlet`的类图如下：

![DispatcherServlet](png/InheritedDispatcherServlet.png)

### Servlet初始化

在`servlet`的生命周期中，`init`方法仅仅会调用一次，在`servlet`销毁时，会调用`destory`方法。

```java
package javax.servlet;

public interface Servlet {
    // 初始化
	void init(ServletConfig var1) throws ServletException;
    // 销毁
	void destroy();
}
```

在`DispatchServlet`的初始化过程中, 默认会从`DispatcherServlet.properties`中读取并初始化一个`HandlerMapping`集合和一个`HandlerApapters`集合。其中`HandlerMapping`用于处理器的映射，即根据请求的url来映射到相关的处理器，以此来实现请求的分发`dispatch`，`HandlerAdapter`是处理器的适配器，用来请求的处理。

```java
package org.springframework.web.servlet;

public class DispatcherServlet extends FrameworkServlet {
	
    @Nullable
	private List<HandlerMapping> handlerMappings;
	@Nullable
	private List<HandlerAdapter> handlerAdapters;
    
	@Override
	protected void onRefresh(ApplicationContext context) {
		initStrategies(context);
	}

	protected void initStrategies(ApplicationContext context) {
        // 初始化HandlerMappings
		initHandlerMappings(context);
        // 初始化HandlerAdatpers
		initHandlerAdapters(context);
	}
}
```

如下是DispatcherServlet.properties配置文件

```properties
# DispatcherServlet.properties
org.springframework.web.servlet.HandlerMapping=org.springframework.web.servlet.handler.BeanNameUrlHandlerMapping,\
	org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerMapping

org.springframework.web.servlet.HandlerAdapter=org.springframework.web.servlet.mvc.HttpRequestHandlerAdapter,\
	org.springframework.web.servlet.mvc.SimpleControllerHandlerAdapter,\
	org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerAdapter
```

这里2类HandlerMapping，`BeanNameUrlHandlerMapping`用于根据bean的名称来根据进行映射，在`RemotingServerConfiguration`类中，定义了一个beanName为`/httpinvoker/*`的组件，那么`/remoting/httpinvoker/*`格式的请求便会被`HttpInvokerServer`这个处理器去处理。`RequestMappingHandlerMapping`则用于控制器(`@Controller`、`@RequestMapping`)的映射。

```java
package org.ironrhino.core.remoting.server;

public class RemotingServerConfiguration {
	@Bean(name = "/httpinvoker/*")
	public HttpInvokerServer httpInvokerServer() {
		return new HttpInvokerServer();
	}
}
```

`BeanNameUrlHandlerMapping`和`RequestMappingHandlerMapping`类图如下:

![](png/HandlerMapping.png)

至此，我们大概知道了微服务调用的HTTP请求，会被`DispathcerServlet`分发给`HttpInvokerServer`来处理，接下来我们就具体看下HttpInvokerServer的处理流程。

## 请求处理

HttpInvokerServer的伪代码如下：

```java
package org.ironrhino.core.remoting.server;
public class HttpInvokerServer implements HttpRequestHandler {
    
    @Autowired
	private ServiceRegistry serviceRegistry;
    
    @Override
    public void handleRequest(HttpServletRequest request, HttpServletResponse response) 		throws ServletException, IOException {
        // 略
    }
}
```

这里handlerRequest主要流程如下：

1. 获取接口名，以及从服务注册中心获取接口的具体实现

   ```java
   String uri = request.getRequestURI();
   // 接口名
   String interfaceName = uri.substring(uri.lastIndexOf('/') + 1);
   // 接口具体实现
   Object target = serviceRegistry.getExportedServices().get(interfaceName);
   ```

2. 从请求头中获取序列化方式

   ```java
   // 获取序列化方式
   HttpInvokerSerializer serializer = HttpInvokerSerializers.forRequest(req);
   ```

3. 请求的输入流中的数据反序列化为RemotingInvocation

   ```java
   // 反序列化
   RemoteInvocation invocation = serializer.readRemoteInvocation(
   			ClassUtils.forName(interfaceName, null),
   			req.getInputStream());
   ```

4. 反射执行

   ```java
   // 反射执行
   Object value = invocation.invoke(target); 
   ```

5. 封装执行结果，并序列化到响应的输出流中

   ```java
   // 结果封装到RemotingInvocationResult
   RemoteInvocationResult result = new RemoteInvocationResult(value);
   // 序列化到response的输出流中
   serializer.writeRemoteInvocationResult(invocation, result, response.getOutputStream());
   ```

