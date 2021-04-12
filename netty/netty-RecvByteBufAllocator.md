# RecvByteBufAllocator接收缓冲区分配器

接收缓冲区分配器`RecvByteBufAllocator`用于从管道中读取消息时, 从`ByteBufAllocator`中分配某个大小的ByteBuf

```java

public interface RecvByteBufAllocator {
    Handle newHandle();

    interface Handle {
        // 从alloc中分配ByteBuf
        ByteBuf allocate(ByteBufAllocator alloc);

        // 下次分配大小
        int guess();

        // 是否继续读取
        boolean continueReading();
    }

}

// DefaultMaxMessagesRecvByteBufAllocator$MaxMessageHandle.java
public abstract class MaxMessageHandle implements ExtendedHandle {
        @Override
        public ByteBuf allocate(ByteBufAllocator alloc) {
            return alloc.ioBuffer(guess());
        }
}
```

## 自适应接收缓冲区分配器

`Channel`中默认使用的接收缓冲区分配器为`AdaptiveRecvByteBufAllocator`

```java
// DefaultChannelConfig.java
public DefaultChannelConfig(Channel channel) {
    this(channel, new AdaptiveRecvByteBufAllocator());
}

protected DefaultChannelConfig(Channel channel, RecvByteBufAllocator allocator) {
    setRecvByteBufAllocator(allocator, channel.metadata());
    this.channel = channel;
}
```

`AdaptiveRecvByteBufAllocator`预先将所有可分配的ByteBuf大小保存在`SIZE_TABLE`数组中, 分别为`16, 32, 48, 64 ... 512, 1024, 2048 ... 2^30`

```java
private static final int[] SIZE_TABLE;

static {
    List<Integer> sizeTable = new ArrayList<Integer>();
    for (int i = 16; i < 512; i += 16) {
        sizeTable.add(i);
    }

    for (int i = 512; i > 0; i <<= 1) {
        sizeTable.add(i);
    }

    SIZE_TABLE = new int[sizeTable.size()];
    for (int i = 0; i < SIZE_TABLE.length; i ++) {
        SIZE_TABLE[i] = sizeTable.get(i);
    }
}
```

 如果要分配的内存的大小为50, 则利用二分法从`SIZE_TABLE`中返回索引3 (64)

 ```java
private static int getSizeTableIndex(final int size) {
    for (int low = 0, high = SIZE_TABLE.length - 1;;) {
        if (high < low) {
            return low;
        }
        if (high == low) {
            return high;
        }

        int mid = low + high >>> 1;
        int a = SIZE_TABLE[mid];
        int b = SIZE_TABLE[mid + 1];
        if (size > b) {
            low = mid + 1;
        } else if (size < a) {
            high = mid - 1;
        } else if (size == a) {
            return mid;
        } else {
            // a, b之间, 返回b的索引
            return mid + 1;
        }
    }
}
 ```

初始读取字节为1024 (1KB)

```java
// 默认
static final int DEFAULT_MINIMUM = 64;
static final int DEFAULT_INITIAL = 1024;
static final int DEFAULT_MAXIMUM = 65536;

// 可调整
private final int minIndex; // 最小索引
private final int maxIndex; // 最大索引
private final int initial; // 初始大小

public AdaptiveRecvByteBufAllocator() {
    this(DEFAULT_MINIMUM, DEFAULT_INITIAL, DEFAULT_MAXIMUM);
}

public Handle newHandle() {
    return new HandleImpl(minIndex, maxIndex, initial);
}

private final class HandleImpl extends MaxMessageHandle {
    private int nextReceiveBufferSize; // 下一次消息读取时, 接收缓冲区大小
    public HandleImpl(int minIndex, int maxIndex, int initial) {
            this.minIndex = minIndex;
            this.maxIndex = maxIndex;

            index = getSizeTableIndex(initial);
            nextReceiveBufferSize = SIZE_TABLE[index];
        }
    }
}
```

根据上次读取的数据大小来调整下次接收缓冲区大小(自适应)

1. 上次读取较小, 则降低下次分配大小

2. 上次读取大于等于上次分配, 则增加下次分配大小 (如果数据量较大, 会不断扩大下次读取大小(索引+4), 保证消息快速读取, )

```java
// AdaptiveRecvByteBufAllocator$HandleImpl.java
@Override
public void lastBytesRead(int bytes) {
    // If we read as much as we asked for we should check if we need to ramp up the size of our next guess.
    // This helps adjust more quickly when large amounts of data is pending and can avoid going back to
    // the selector to check for more data. Going back to the selector can add significant latency for large
    // data transfers.
    // 更快的进行调整, 避免返回selector去读取更多的数据(会增加大量数据传输时的延迟)
    if (bytes == attemptedBytesRead()) {
        // 上次分配的缓冲区已被读满, 可能有较大的数据, 下次读取分配更大的缓冲区
        record(bytes);
    }
    super.lastBytesRead(bytes);
}

@Override
public int guess() {
    return nextReceiveBufferSize;
}

private static final int INDEX_DECREMENT = 1;
private static final int INDEX_INCREMENT = 4;


private void record(int actualReadBytes) {
    if (actualReadBytes <= SIZE_TABLE[max(0, index - INDEX_DECREMENT - 1)]) {
        if (decreaseNow) {
            index = max(index - INDEX_DECREMENT, minIndex);
            nextReceiveBufferSize = SIZE_TABLE[index];
            decreaseNow = false;
        } else {
            decreaseNow = true;
        }
    } else if (actualReadBytes >= nextReceiveBufferSize) {
        index = min(index + INDEX_INCREMENT, maxIndex);
        nextReceiveBufferSize = SIZE_TABLE[index];
        decreaseNow = false;
    }
}

@Override
public void readComplete() {
    record(totalBytesRead());
}
```

## 消息读取流程(加深理解)

从管道中读取消息至 byteBuffer, 每次读取完毕都会回调 channelRead()方法, 读取完毕后, 回调 readComplete() 方法

```java
// AbstractNioByteChannel.java
protected class NioByteUnsafe extends AbstractNioUnsafe {

    public final void read() {
        final ByteBufAllocator allocator = config.getAllocator();
        final RecvByteBufAllocator.Handle allocHandle = recvBufAllocHandle();
        allocHandle.reset(config);

        ByteBuf byteBuf = null;
        boolean close = false;
        try {
            do {
                // 分配ByteBuf
                byteBuf = allocHandle.allocate(allocator);
                // 读取消息到byteBuf中, 并记录读取字节大小
                allocHandle.lastBytesRead(doReadBytes(byteBuf));
                if (allocHandle.lastBytesRead() <= 0) {
                    // nothing was read. release the buffer.
                    byteBuf.release();
                    byteBuf = null;
                    close = allocHandle.lastBytesRead() < 0;
                    if (close) {
                        // There is nothing left to read as we received an EOF.
                        readPending = false;
                    }
                    break;
                }

                allocHandle.incMessagesRead(1);
                readPending = false;

                // 回调处理器的channelRead()方法
                pipeline.fireChannelRead(byteBuf);
                byteBuf = null;

                // 是否继续读 (上次写满了, 则需要继续读)
            } while (allocHandle.continueReading());

            allocHandle.readComplete();
            pipeline.fireChannelReadComplete();

            if (close) {
                closeOnRead(pipeline);
            }
        }
    }
}
```

尝试读取消息的大小为 byteBuf的可写大小, 之后从channel读取消息, 写入byteBuf中

```java
// NioSocketChannel.java
@Override
protected int doReadBytes(ByteBuf byteBuf) throws Exception {
    final RecvByteBufAllocator.Handle allocHandle = unsafe().recvBufAllocHandle();
    allocHandle.attemptedBytesRead(byteBuf.writableBytes());
    return byteBuf.writeBytes(javaChannel(), allocHandle.attemptedBytesRead());
}
```

这里defaultMaybeMoreSupplier是 `attemptedBytesRead == lastBytesRead`, 也就是上一次消息读取是不是将缓冲区写满了, 没有写满, 则不用继续读取消息, 否则可能消息未读取完毕, 需要继续读

```java
// MaxMessageHandle.java
@Override
public boolean continueReading() {
    return continueReading(defaultMaybeMoreSupplier);
}

@Override
public boolean continueReading(UncheckedBooleanSupplier maybeMoreDataSupplier) {
    return config.isAutoRead() &&
            (!respectMaybeMoreData || maybeMoreDataSupplier.get()) &&
            totalMessages < maxMessagePerRead &&
            totalBytesRead > 0;
}
```