# !/bin/bash
# author: zhaomingming
# shell脚本编程入门

# 变量
name="ZhaoMingMing"
readonly name

# 字符串 
# 双引号
echo '[============= 字符串 ===============]'
greeting="Hello, I am ${name}"
echo "greeting: \"${greeting}\""
# 单引号
greeting='Hello, I am ${name}'
echo "greeting: \"${greeting}\""
# 字符串长度
echo "greeting length is: ${#greeting}"
# 字符串提取
echo '${greeting:14:4} is:'"\"${greeting:14:4}\""


# 数组
echo '[=============  数组  ===============]'
arr=("Java" "C++" "Go" "Kotlin")
# 全部元素
echo ${arr[*]}
echo ${arr[@]}
# 索引
echo ${arr[0]}
# 长度
echo "arr.length = ${#arr[*]}"


# 基本运算
# 运算
echo '[============  算术运算  ==============]'
i=10
j=20
echo "i = $i, j= $j"
echo "i + j: `expr $i + $j`"
echo "i - j: `expr $i - $j`"
echo "i * j: `expr $i \* $j`"
echo "i / j: `expr $i / $j`"
echo "i % j: `expr $i % $j`"

echo '$[ i + j ]: '$[ i + j ]
echo '$[ i * j ]: '$[ i * j ]

# 关系运算符(-eq -ne -gt -lt -ge -le)
echo '[============  关系运算  ==============]'
if [ $i -eq $j ]
then
    echo "i = j";
elif [ $i -gt $j ]
then
    echo "i > j";
else
    echo "i < j";
fi

echo $[ i == j ]
echo $[ i != j ]
echo $[ i > j ]
echo $[ i < j ]

# 布尔运算
# 1. 非运算: ! 
# 2. 或运算(or):  -o
# 3. 与运算(and): -a
echo '[============  布尔运算  ==============]'
if [ $i != $j ]
then
    echo "i != j"
else
    echo "i == j"
fi

if [ $i -ge 10 -a $j -ge 10 ]
then
    echo '$i -ge 10 -a $j -ge 10 is true'
fi

if [ $i -gt 10 -o $j -gt 10 ]
then
    echo '$i -gt 10 -o $j -gt 10 is true'
fi


# 逻辑运算
echo '[============  逻辑运算  ==============]'
if [[ $i -ge 10 && $j -ge 10 ]]
then
    echo '[$i -ge 10 && $j -ge 10] is true'
fi

if [[ $i -gt 10 || $j -gt 10 ]]
then
    echo '[$i -gt 10 || $j -gt 10] is true'
fi

# 字符串运算符
# == 是否相等
# != 是否不相等
# -z 长度是否为0
# -n 长度是否不为0
# $ 是否为空
echo '[============  字符串运算  ==============]'
notEmpty="Hello"
empty=""
if [ -z $empty ]
    then echo '${empty} length is 0'
fi

if [ -n $notEmpty ]
    then echo '${notEmpty} length > 0'
fi

if [ $ $n ]
    then echo '${n} is null'
fi

# 文件测试运算符
# -b 是否为块设备
# -e 文件是否存在
# -d 文件是否存在且是目录文件
# -f 文件是否存在且是普通文件
# -r -w -x 可读 可写 可执行
# -s 大小是否为0

echo '[===========  文件测试运算符  =============]'
d=`pwd`
if [ -d $d ]
then echo "'$d' is a directory."
fi

f='test.temp'
if [[ ! -e $f ]]
then 
    `touch $f`
fi

if [ -e $f ]
then echo "'$f' is a file."
fi

if [ -r $f ]
then echo "'$f' is readable."
else echo "'$f' isn't readable."
fi

if [ -w $f ]
then echo "'$f' is writable."
else echo "'$f' isn't writable."
fi

if [ -x $f ]
then echo "'$f' is executable."
else echo "'$f' isn't executable."
fi

`rm $f`

echo "[============  ECHO  ==============]"
if [ `uname -s` == "DARWIN" ] # mac操作系统
then
    echo "escape! \n";
    echo "Don't wrap! \c"; # \c 不换行
else
    echo -e "escape! \n";
    echo -e "Don't wrap! \c"; # \c 不换行
fi
echo "Hello, world."

echo "echo to file" >> test.temp
echo `cat test.temp`
`rm test.temp`

echo `date`

echo "[============  PRINTF  ==============]"
printf "%-10s %-4s %-4s %-4s\n" name sex age weight
printf "%-10s %-4s %-4d %-4.2f\n" mingming man 23 75.23456

printf "%s %s %s\n" a b c d e f g h i j k l m n

echo "[============  TEST  ==============]"
if test $i -gt $j
then
    echo "i > j"
elif test $[i] -lt $[j]
then
    echo "i < j"
else
    echo "i = j"
fi

s1="s1"
s2="s2"
if test $s1 == $s2
then
    echo "s1 = s2"
else
    echo "s1 != s2"
fi

if test -n $s1; then echo "s1 length != 0"; fi

if test ! -e $f
then 
    `touch $f`
fi

if test -e $f
then echo "'$f' is a file."
fi

if test -r $f
then echo "'$f' is readable."
else echo "'$f' isn't readable."
fi

if test -w $f
then echo "'$f' is writable."
else echo "'$f' isn't writable."
fi

if test -x $f
then echo "'$f' is executable."
else echo "'$f' isn't executable."
fi

`rm $f`

echo "[============  流程控制  ==============]"
echo TODO

# for循环
for each in zhaomingming mingming; do echo "Hello, I'm ${each}"; done;