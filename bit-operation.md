# 位操作

**异或**
```java
0 ^ 0 = 0
1 ^ 0 = 1
val ^ 0 = val 任何整数与0异或都是它本身
val ^ val = 0 两个相同的数异或为0
```

**是否为2的次方数**
```java
boolean isPowerOfTwo(int val) {
    return val >= 0 && (val & -val) == val;
}

// 0b00000001 00000000 00000000 00000000
//                                     &
// 0b11111111 00000000 00000000 00000000
// 0b00000001 00000000 00000000 00000000
```

**2的次方数的取模**
```java
T next() {
    return array[counter ++ & array.length - 1];
}
// 0b00000000 11111111 00000100 00000000
//                                     &
// 0b00000000 00000000 00000011 11111111
// 0b00000000 00000000 00000000 00000000

// 0b00000000 11111111 00000000 11111111
//                                     &
// 0b00000000 00000000 00000011 11111111
// 0b00000000 00000000 00000000 11111111
```
> Netty中`DefaultEventExecutorChooserFactory`, 当事件循环组大小为2的次方数时, 则使用这种取模方式.

**是否为4(2的次方数)的倍数**
```java
boolean isMultipleOfFour(int val) {
    return (val & 4 - 1) == 0; // val & 3 == 0
}
```
> JDK java.time.Year中闰年的判断
    ```
    public static boolean isLeap(long year) {
        return ((year & 3) == 0) && ((year % 100) != 0 || (year % 400) == 0);
    }
    ```