#!/bin/bash
#author zhaomingming
#url: https://www.zhihu.com/question/267069065
#心形图案❤️ 

# 浮点数除法结果保存至d变量
d=0
function div() {
	d=`echo "$1 $2"|awk '{printf("%f", $1/$2)}'`	
}

# 浮点数乘法结果保存至m变量
m=0
function mul() {
	m=`echo "$1 $2"|awk '{printf("%f", $1*$2)}'`
}

# 终端宽和高比例
SCALE=0.45
X_LENGTH=60
Y_LENGTH=28
X_LENGTH_HALF=$((X_LENGTH/2))
Y_LENGTH_HALF=$((Y_LENGTH/2))

# 心形线坐标系x坐标
x=0
function xl() {
	mul $(($1 - X_LENGTH_HALF)) $SCALE
	div $m 10
	x=$d
}

# 心形线实际y坐标
y=0
function yl() {
	div $((Y_LENGTH_HALF - $1)) 10
	y=$d
}
# 心形线 (x^2+y^2-1)^3-(x^2*y^3) = 0
h=0
function heart() {
	h=`echo "$1" "$2"|awk '{printf("%f",($1*$1+$2*$2-1)**3-$1*$1*($2**3))}'`
}

for ((j=0;j<$Y_LENGTH;j++))
do
	for ((i=0;i<$X_LENGTH;i++))
	do
		xl $i
		yl $j
		heart $x $y 
		if [ `echo "$h < 0"|bc` -eq 1 ]
		then
			printf "\033[31m%s\033[0m" m
		else
			printf "%s" " "
		fi
	done
	printf "\n"
done
