# Netty

## 概述

Netty is an asynchronous event-driven network application framework 
for rapid development of maintainable high performance protocol servers & clients.

Netty是一个异步**事件驱动**网络应用框架, 

1. 事件驱动模型
2. 统一的API, 方便使用
3. 多协议支持、自定义协议
4. 支持零拷贝的Byte Buffer

## 特性

### 设计

1. Unified API for various transport types - blocking and non-blocking socket
2. Based on a flexible and extensible event model which allows clear separation of concerns
3. Highly customizable thread model - single thread, one or more thread pools such as SEDA
4. True connectionless datagram socket support

> SEDA is an acronym for staged event-driven architecture, and decomposes a complex, event-driven application into a set of stages connected by queues. This design avoids the high overhead associated with thread-based concurrency models, and decouples event and thread scheduling from application logic. By performing admission control on each event queue, the service can be well-conditioned to load, preventing resources from being overcommitted when demand exceeds service capacity.

> 阶段性事件驱动架构/阶段式服务器架构, SEDA 是`staged event-driven architecture`的缩写, 将复杂的、事件驱动应用拆分为一些列的通过队列连接的阶段. 避免基于线程的并发模型的高负载问题, 将事件和线程调度从应用逻辑中解偶, 通过对每一个事件队列的准入控制, 服务能够在更好的条件下负载, 在需求超过服务容量时, 保护资源不被过度使用. 

翻译

1. 适用于不同传输类型的统一API - 阻塞和非阻塞socket
2. 基于灵活可扩展的事件模型, 可将关注点明确分离
3. 高可自定义的线程模型 - 单线程、一个或多个线程池如SEDA
4. 真正的无连接数据报支持

### 性能

1. Better throughput, lower latency 高吞吐量、低延迟
2. Less resource consumption 更少的资源消耗
3. Minimized unnecessary memory copy 最小的不必要内存拷贝

## 构成

![components](png/components.png)

### 协议
1. `HTTP & WebSocket`
2. `SSL StartTLS`
3. `Google Protobuf`, 结构化的数据，跨语言(Java、Python、C++)、跨平台
4. `zlib/gzip compression` 压缩
5. `Large File Transfer` 大文件传输
6. `RTSP` - `Real Time Streaming Protocol`网络流媒体协议
7. `Legacy Text|Binary Protocals`旧的文本｜二进制协议

### 核心
1. 可扩展的事件模型
2. 通用的通信API
3. 有零拷贝能力的字节缓冲区

## 参考

1. [https://netty.io](https://netty.io)
2. [SEDA](https://web.archive.org/web/20061130052025/http://www.eecs.harvard.edu/%7Emdw/proj/seda/#downloads)