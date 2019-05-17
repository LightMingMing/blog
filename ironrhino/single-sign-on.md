# 铁犀牛-单点登录

## 概念

单点登录,英文全称Single sign-On, 简称SSO

单点登录用于实现在多个应用系统中，用户的统一管理以及用户的统一登录。用户只需要登录一次就可以访问其它所有系统。对于我们这些后台系统来说，能够用于减少开发、测试、运营等人员在多个系统操作时登录的次数；如果是面向用户的系统，用户在多个系统进行切换时，不需要重复登录，提升客户体验。

## 实现原理

### 单系统登录

在讲解单点登录之前，我们先看看铁犀牛单系统登录是如何实现的

当前我们各个后台系统，都是采用browser/server架构，http作为通信协议。而http是一种基于请求做出响应的无状态协议，也就是每一次请求的到来，系统并不会与之前请求相关联。因此需要一种方式来维持客户端与服务端的状态，这就是会话机制。

一种简单的会话机制是在客户端第一次请求时，服务端创建一个session，并保存在自己内存中，然后将session的id返回给客户端，保存到客户端浏览器的cookie中，客户端的下次请求时，会自动附带该cookie信息，这样服务端根据id就能对用户进行识别。

铁犀牛提供了两种会话机制

第一种方式是sessionTracker和sessionCookie都保存在客户端，其中sessionTracker中携带着本次会话的创建时间以及最近访问时间，而sessionCookie是加密后的用户信息，只有用户登录后才会在客户端存在, 我们测试环境用的就是这种方式。

第二种方式是sessionTracker保存在客户端，sessionCookie保存在redis缓存中。生产环境使用的便是这种方式。

### 单点登录

结合单系统的登录会话机制，要想实现单点登录，那么需要满足2个条件

1. 各应用的客户端要cookie共享
2. 各应用的服务端对同一个的会话的鉴权要统一

这样用户在浏览器访问不同的应用时的请求，都能够携带同一个cookie, 而服务端验证的统一则会由一致的验证结果，实现统一登录。

#### 客户端同父域的Cookie共享

cookie是不能够跨域的，即所在域为portal.hncy58.internal的cookie，是不能被携带到域名为app.hncy58.internal的应用中的。但是cookie的域可以设为父域，即我们可以将域名为portal.hncy58.internal应用cookie的域设为'.hncy58.internal', 这样访问域名为app.hncy58.internal的应用时，能够携带域为'.hncy58.internal'的cookie。以此达到同父域应用客户端的cookie共享。

#### 服务端鉴权统一

由于服务端系统的繁多，不同应用使用自己单独的鉴权方式的话则不太理想，很难让它们的鉴权结果一致。因此需要一个统一的登录中心或门户，用于统一验证。

用户首次请求时，会自动跳转到portal登录中心的登录界面，也就是用户会在portal中心登录，认证通过后，portal服务中心会生成所在的域为应用父域的cookie返回给客户端。

之后用户在任何一个应用的客户端发起的请求，都会携带该cookie，并向portal登录中心发送地址为/api/user/@self的请求，获取在portal登录中心登录的用户，并将该用户的权限与所在应用系统的权限进行合并。

## 单机单点登录环境搭建

### 修改hosts文件

```
127.0.0.1 portal.hncy58.internal # 登录中心域名
127.0.0.1 app.hncy58.internal    # 业务系统域名
```

### tomcat配置虚拟主机

修改/conf/server.xml文件如下

```
<?xml version="1.0" encoding="UTF-8"?>
<Server port="8005" shutdown="SHUTDOWN">
  <Service name="Catalina">
    <Connector connectionTimeout="20000" maxPostSize="4194304" port="8080" server="Ironrhino"/>
    <Engine defaultHost="localhost" name="Catalina">
      <Host appBase="webapps" autoDeploy="false" name="localhost" unpackWARs="true">
      </Host>
      <Host appBase="webapps" autoDeploy="false" name="portal.hncy58.internal" unpackWARs="true">
      </Host>
    </Engine>
  </Service>
</Server>
```

添加/conf/Catalina/localhost/ROOT.xml文件

```java
<Context docBase="{portal工程目录}/webapp" reloadable="false"/>
```

添加/conf/Catalina/portal.hncy58.internal/ROOT.xml

```java
<Context docBase="{app工程目录}/webapp" reloadable="false"/>
```

### 系统配置

业务系统app配置登录中心portal的地址

```
portal.baseUrl=http://portal.hncy58.internal:8080
```

登录中心portal配置全局cookie, 使cookie的域设为父域

```
globalCookie=true
```

### 效果

浏览器中输入http://app.hncy58.internal:8080，发现可页面跳转到http://portal.hncy58.internal:8080/login?targetUrl=http%3A%2F%2Fapp.hncy58.internal%3A8080%2F 证明环境搭建成功

![](/png/sso-login.png)

登录后观察cookie, 如下可看到cookie的域为.hncy58.internal

![](/png/sso-cookie.png)

注意事项：如果有设置代理的话，需要关闭代理

