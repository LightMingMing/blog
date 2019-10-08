# 微信公众号登录流程
!['wechat-login'](png/wechat-login.png)

**会话失效时, 自动登录流程**
1. 用户正常操作, 点击菜单或某一链接, 如"去借钱"
2. 公众号客户端向服务端发送请求
    ```yaml
    GET /frontend/loan/product/goToLoan HTTP/1.1
    Host: wx.hncy58.com
    Connection: close
    Upgrade-Insecure-Requests: 1
    User-Agent: Mozilla/5.0 (Linux; Android 8.0.0; MI 6 Build/OPR1.170623.027; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/66.0.3359.126 MQQBrowser/6.2 TBS/044904 Mobile Safari/537.36 MMWEBID/7600 MicroMessenger/7.0.7.1521(0x27000735) Process/tools NetType/WIFI Language/zh_CN
    Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,image/wxpic,image/sharpp,image/apng,image/tpg,*/*;q=0.8
    Accept-Encoding: gzip, deflate
    Accept-Language: zh-CN,en-US;q=0.9
    ```
3. 服务端响应  
    检测到客户端会话过期(验证T有无对应的Session, 没有T或T失效, 会重新设置一个), 要求客户端访问开发平台获取授权码`code`
    ```yaml
    HTTP/1.1 302 Found
    connection: close
    Date: Tue, 08 Oct 2019 09:20:24 GMT
    Content-Length: 0
    Server: Apache-Coyote/1.1
    X-Powered-By: Ironrhino
    X-Frame-Options: SAMEORIGIN
    X-Request-Id: 0obrg3KHR9C2VHbckv9t2S
    Set-Cookie: T=QBicKNi0YVPWYgYSJnsDs6TbTmzVC6Z4; Path=/; HttpOnly
    Location: https://open.weixin.qq.com/connect/oauth2/authorize?appid=wxc24046ea8e912ed7&redirect_uri=https%3A%2F%2Fwx.hncy58.com%2Fredirect&response_type=code&scope=snsapi_base&state=%2Ffrontend%2Floan%2Fproduct%2FgoToLoan#wechat_redirect
    ```
4. 客户端访问微信开放平台
5. 微信开发平台返回授权码
6. 客户端将授权码发送至服务端
    ```yaml
    GET /redirect?code=0119FRDI08RPqf2Df5EI0CMNDI09FRDN&state=%2Ffrontend%2Floan%2Fproduct%2FgoToLoan HTTP/1.1
    Host: wx.hncy58.com
    Connection: close
    Upgrade-Insecure-Requests: 1
    User-Agent: Mozilla/5.0 (Linux; Android 8.0.0; MI 6 Build/OPR1.170623.027; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/66.0.3359.126 MQQBrowser/6.2 TBS/044904 Mobile Safari/537.36 MMWEBID/7600 MicroMessenger/7.0.7.1521(0x27000735) Process/tools NetType/WIFI Language/zh_CN
    Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,image/wxpic,image/sharpp,image/apng,image/tpg,*/*;q=0.8
    Accept-Encoding: gzip, deflate
    Accept-Language: zh-CN,en-US;q=0.9
    Cookie: T=QBicKNi0YVPWYgYSJnsDs6TbTmzVC6Z4
    ```
7. 服务端访问开发平台获取客户`openID`
8. 开放平台返回客户`openId`  
    服务端获取到客户`openId`后, 创建`session`保存到缓存中, 并建立Tracker->Session的映射关系
9. 服务端响应  
    将用户的`openId`设置到客户端的`cookie`中, 并要求客户端重新发送请求
    ```yaml
    HTTP/1.1 302 Found
    connection: close
    Date: Tue, 08 Oct 2019 09:20:35 GMT
    Content-Length: 0
    Server: Apache-Coyote/1.1
    X-Powered-By: Ironrhino
    X-Frame-Options: SAMEORIGIN
    X-Request-Id: 5Zj2bqhtSuMyMnIyrzuv17
    Set-Cookie: UU=oCQL-wcUs***************ApGY; Path=/
    X-Redirect-To: /frontend/loan/product/goToLoan
    Location: https://wx.hncy58.com/frontend/loan/product/goToLoan
    ```
10. 客户端再次请求'去借款'页面
11. 服务端正常响应
12. 用户进入到"去借款"页面

> 会话未失效时, 只会有1, 2, 11, 12这几个过程。但是对用户而言, 不管会话是什么状态, 都是只能感知到1和12这两个过程, 中间过程无感知。