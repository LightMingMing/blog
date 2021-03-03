# Java NIO

## NIO 组件

### Channel

通道代表和硬件设备、文件、socket之间的一个连接, 支持非阻塞的I/O操作, 同时支持读写操作(Java流对象一般只能读或写), 并且可被一个selector多路复用

如下是分别创建一个服务端套接字通道和客户端套接字通道
```java
// 创建ServerSocketChannel
ServerSocketChannel serverSocketChannel = ServerSocketChannel.open();
// 非阻塞
serverSocketChannel.configureBlocking(false);

// 创建SocketChannel
SocketChannel socketChannel = SocketChannel.open();
// 非阻塞
socketChannel.configureBlocking(false);
```

### Selector

选择器用于对通道进行多路复用

```java
// 创建Selector
Selector selector = Selector.open();
```

通道及其感兴趣的事件注册至选择器
```java
//  ServerSocketChannel注册
serverSocketChannel.register(selector, SelectionKey.OP_ACCEPT); // ACCEPT事件

// SocketChannel注册
socketChannel.register(selector, SelectionKey.OP_READ); // READ事件
```

当通道感兴趣的事件发生时, 可通过`select`方法获取事件对应的通道 (`epoll`系统调用)


**select相关方法**

#### selectNow()


返回I/0操作就绪的通道的个数, 后续可通过`selectedKeys()`方法, 获取选中的key集

该方法会立即返回, 不会阻塞, 返回0, 说明上次选择后, 到现在没有通道可选择

调用该方法会清除之前`wakeup()`方法带来的影响

```java
public abstract int selectNow() throws IOException;
```

#### select(long)

限时阻塞的select操作, 以下任意条件满足才会返回:

    1. 当至少有一个channel可被选择
    2. 其它线程执行了selector的`wakeup()`方法
    3. 当前线程被中断
    4. 阻塞到达超时时间

```java
public abstract int select(long timeout) throws IOException;
```

#### select()

永久阻塞的select操作, 以下任意条件满足才会返回:

    1. 当至少有一个channel可被选择
    2. 其它线程执行了selector的`wakeup()`方法
    3. 当前线程被中断

```java
public abstract int select() throws IOException;
```

#### JDK11 新的select API 
JDK11 引入了新的selectAPI, 可以将事件的处理逻辑直接传递给select方法, 后续可以不用在调用`selectedKeys`方法

```java
// selectNow
public int selectNow(Consumer<SelectionKey> action) throws IOException {
    return doSelect(Objects.requireNonNull(action), -1);
}

// select
public int select(Consumer<SelectionKey> action) throws IOException {
    return select(action, 0);
}

// select
public int select(Consumer<SelectionKey> action, long timeout) throws IOException {
    if (timeout < 0)
        throw new IllegalArgumentException("Negative timeout");
    return doSelect(Objects.requireNonNull(action), timeout);
}
```

### Buffer

对channel进行读写, 采用的是字节缓存区(可以理解为数组)

```java
// SocketChannel.java
public abstract int read(ByteBuffer dst) throws IOException;

public abstract int write(ByteBuffer src) throws IOException;
```

```java
// Buffer.java

// Invariants: mark <= position <= limit <= capacity
private int mark = -1;
private int position = 0;
private int limit;
private int capacity;
```


## 示例

```java
// 单线程版本
try (ServerSocketChannel serverSocketChannel = ServerSocketChannel.open();
        Selector selector = Selector.open()) {
    serverSocketChannel.configureBlocking(false);
    serverSocketChannel.register(selector, SelectionKey.OP_ACCEPT);
    serverSocketChannel.bind(new InetSocketAddress(8080));

    for (; ; ) {
        selector.select(s -> {
            if (s.isAcceptable()) {
                // 处理连接
                try {
                    SocketChannel socketChannel = serverSocketChannel.accept();
                    socketChannel.configureBlocking(false);
                    // 注册新的socketChannel至选择器
                    socketChannel.register(selector, SelectionKey.OP_READ);
                } catch (IOException e) {
                    // ignore
                }
            } else if (s.isReadable()) {
                // 读取数据
                SocketChannel socketChannel = (SocketChannel) s.channel();
                ByteBuffer buffer = ByteBuffer.allocate(200);
                try {
                    socketChannel.read(buffer);
                    buffer.flip();
                    System.out.print(StandardCharsets.UTF_8.decode(buffer));
                    socketChannel.write(StandardCharsets.UTF_8.encode("你好\n"));
                } catch (IOException e) {
                    // ignore
                }
            }
        });
    }
}
```