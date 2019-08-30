# Shell脚本编程入门

## 变量
```bash
# 声明变量
name="zhaomingming"
# 变量使用
$name 或者 ${name}
# 只读变量
readonly name
# 删除变量
unset name
```

## 字符串
```bash
# 双引号, 可以使用变量, 可以使用转义字符
greeting="Hello, I am ${name} !"
# 单引号, 原文展示, 并且不可以使用转义字符
greeting='Hello, I am ${name} !'
# 长度
${#greeting}
# 字符串提取
echo ${greeting:14:4}
```

## 数组
```bash
arr=("Java" "C++" "Go" "Kotlin")
# 全部元素
echo ${arr[*]}
echo ${arr[@]}
# 索引
echo ${arr[0]}
# 长度
echo "arr.length = ${#arr[*]}"
```

## 基本运算符
### 算术运算符
```bash
i=10
j=20
echo "i + j: `expr $i + $j`"
echo "i - j: `expr $i - $j`"
echo "i * j: `expr $i \* $j`" # 注意要加 \
echo "i / j: `expr $i / $j`"
echo "i % j: `expr $i % $j`"

# []也可以执行基本运算
echo '$[ i + j ]: '$[ i + j ]
echo '$[ i * j ]: '$[ i * j ] # 这里不加 \
```
### 关系运算
```bash
# 等于 不等于 大于 小于 大于等于 小于等于
# -eq -ne -gt -lt -ge -le
if [ $i -eq $j ]
then
    echo "$i -eq $j: i = j";
elif [ $i -gt $j ]
then
    echo "$i -gt $j: i > j";
else
    echo "$i -lt $j: i < j";
fi
# 或者使用[]
echo $[ i == j ]
echo $[ i != j ]
echo $[ i > j ]
echo $[ i < j ]
```
### 布尔运算符
```bash
# ! 非运算
# -o 或运算or
# -a 与运算and
if [ $i -gt 10 -o $j -gt 10 ]
then
    echo '$i -gt 10 -o $j -gt 10 is true'
fi
```
### 逻辑运算
```bash
# || 或运算
# && 与运算
if [[ $i -gt 10 || $j -gt 10 ]]
then
    echo '[$i -gt 10 || $j -gt 10] is true'
fi
```
### 字符串运算符
```bash
# == 是否相等  != 是否不相等
# -z 长度是否为0  -n 长度是否不为0
# $ 是否为空
```
### 文件测试运算符
```bash
# -b 是否为块设备
# -e 文件是否存在
# -d 文件是否存在且是目录文件
# -f 文件是否存在且是普通文件
# -r -w -x 可读 可写 可执行
# -s 大小是否为0

d=`pwd`
if [ -d $d ]
then echo "'$d' is a directory"
fi
```

## echo
```bash
# -e 转义 注: mac上似乎不用-e
echo -e "escape! \n"
# \c 不换行
echo -e "not change"

if [ `uname -s` == "DARWIN" ] # mac操作系统
then
    echo "escape! \n";
    echo "Don't wrap! \c"; # \c 不换行
else
    echo -e "escape! \n";
    echo -e "Don't wrap! \c"; # \c 不换行
fi
# 输出至文件
echo "Hello, world." >> test.temp
echo `cat test.temp`
`rm test.temp`
# 打印日期
echo `date`
```

## printf
```bash
# printf  format-string  [arguments...]
# 类似c语言
printf "%-10s %-4s %-4s %-4s\n" name sex age weight
printf "%-10s %-4s %-4d %-4.2f\n" mingming man 23 75.23456

printf "%s %s %s\n" a b c d e f g h i j k l m n
```

## test
```bash
# 数值测试
# -ge -le -gt -lt -eq -ne
if test $i -gt $j
then
    echo "i > j"
elif test $[i] -lt $[j]
then
    echo "i < j"
else
    echo "i = j"
fi

# 字符串测试
# == != -z(zero) -n(not zoro)
s1="s1"
s2="s2"
if test $s1 == $s2
then
    echo "s1 = s2"
else
    echo "s1 != s2"
fi

if test -n $s1; then echo "s1 length != 0"; fi

# 文件判断 与文件测试符一致
# -e -r -w -x -d -f ...
if test ! -e $f #文件不存在则创建
then 
    `touch $f`
fi
`rm $f` # 文件删除
```

## TODO 流程控制
### if
```bash
# 单行写法
# if condition; then command1; command2; fi
# if condition; then command1; else command2; fi
# if condition; then command1; elif condition2; then command2; else command3; fi
if [ $i -lt $j ]; then echo "i < j"; elif [ $i -gt $j ]; then echo "i > j"; else echo "i = j"; fi
```
### for
```bash
# 单行写法
# for each in item1 item2 item3; do command1; command2; command3; done
for each in zhaomingming mingming; do echo "Hello, I'm ${each}"; done;
```

## TODO 函数...


## 参考链接
> [菜鸟shell教程](https://www.runoob.com/linux/linux-shell-echo.html)  
> [操作系统判断的指令:uname](https://gohom.win/2015/06/12/uname-shell/)  