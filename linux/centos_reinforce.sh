#!/bin/bash
#author: zhaomingming
#CentOS操作系统安全加固脚本

#TODO 配置DNS服务器
nameservers=()

# 是否需要重启服务, 0否 1是
sshd_restart=0

# 警告, 红色字体
function warn() {
    printf "\033[31m%s \033[0m" $1
    printf "\n"
}

# 调试, 蓝色字体
function debug() {
    printf "\033[34m%s \033[0m" $1
    printf "\n"
}

# 信息, 黄色字体
function info() {
    printf "\033[33m%s \033[0m" $1
    printf "\n"
}


# 操作系统检测
# CentOS 操作系统版本:
# cat /etc/redhat-release
# CentOS release 6.6 (Final)
# CentOS Linux release 7.6.1810 (Core)
# Ubuntu :
# lsb_release -r
# Release:	12.04
version=0
if [ -e '/etc/redhat-release' ]
then
    release=`cat /etc/redhat-release`
    version=`echo $release | awk '{printf("%s", $4)}' | awk -F. '{printf("%d", $1)}'`
    if [ $version -eq 0 ]
    then
        version=`echo $release | awk '{printf("%s", $3)}' | awk -F. '{printf("%d", $1)}'`
    fi
else
    if [ -n `command -v lsb_released` ]
    then
        version=`lsb_release -r | awk '{printf("%s", $2)}' | awk -F. '{printf("%d", $1)}'`
    fi
fi
info "操作系统版本: $version"


# 要求centos系统
if [[ ! ( $version == 7 || $version == 6 ) ]]
then
    warn "要求CentOS系统..."
    exit
fi

# 系统时间配置规范
# TODO 确认 100.64.110.114
# echo "0 0 * * * /usr/sbin/ntpdate 100.64.110.114" >> /var/spool/cron/root

# DNS配置规范
info "# DNS配置规范"

info "1. 配置主机解析顺序(/etc/host.conf)"
order=`cat /etc/host.conf | grep "^order"`
if [[ -z $order ]]
then
    warn "未配置order, 进行配置..."
    sed -i '1i order local,bind4' /etc/host.conf
else
    v=`echo $order | awk '{printf("%s", $2)}'`
    debug "当前配置: $order 截取后: $v"
    if [ $v != "local,bind4" ]
    then
        sed -i 's/^order.*/order local,bind4/g' /etc/host.conf
    fi
fi
info "2. 允许一个主机对应多个IP(/etc/host.conf)"
multi=`cat /etc/host.conf | grep "^multi"`
if [[ -z $multi ]]
then
    warn "未配置multi, 进行配置..."
    sed -i '$a multi on' /etc/host.conf
else
    v=`echo $multi | awk '{printf("%s", $2)}'`
    debug "当前配置: $multi 截取后: $v"
    if [ $v != "on" ]
    then
        warn "非规范配置, 进行更改..."
        sed -i 's/^multi.*/multi on/g' /etc/host.conf
    fi
fi
info "3. 配置DNS服务器(/etc/resolv.conf)"
for ((i=0;i<${#nameservers[*]};i++))
do
    v=`cat /etc/resolv.conf | grep "nameserver ${nameservers[i]}"`
    if [ -z "$v" ]
    then
        warn "未配置DNS服务器: ${nameservers[i]}, 进行配置..."
        sed -i '$a nameserver '${nameservers[i]} /etc/resolv.conf
    fi
done

info "4. 关闭NetworkManager服务"
if [[ $version == 6 ]]
then
    service NetworkManager stop
    chkconfig NetworkManager off
elif [[ $version == 7 ]]
then
    systemctl stop NetworkManager
    systemctl disable NetworkManager
fi

info "5. 关闭SSH启用域名服务"
useDNS=`cat /etc/ssh/sshd_config | grep '^UseDNS'`
if [[ -z $useDNS ]]
then
    warn "未配置UseDNS, 进行配置..."
    sed -i '$a UseDNS no' /etc/ssh/sshd_config
    sshd_restart=1
else
    v=`echo $useDNS | awk '{printf("%s", $2)}'`
    debug "当前配置: $useDNS 截取后: $v"
    if [ $v != "no" ]
    then
        warn "非规范配置, 进行更改..."
        sed -i 's/^UseDNS.*/UseDNS no/g' /etc/ssh/sshd_config
        sshd_restart=1
    fi
fi

info "6. 开启DNS Cache功能"
if [[ -z `command -v nscd` ]]
then
    if [[ $version == 6 || $version == 7 ]]
    then
        yum -y install nscd
    fi
fi
if [[ $version == 6 ]]
then
    service nscd start
    chkconfig nscd on
elif [[ $version == 7 ]]
then
    systemctl start nscd
    systemctl enable nscdfi
fi
printf "\n"

# 系统参数配置规范
info "# 系统参数配置规范"
info "1. 系统网络参数"

ks=("fs.file-max" "net.ipv4.ip_local_port_range" "net.ipv4.tcp_tw_reuse" "net.ipv4.tcp_tw_recycle" "net.ipv4.tcp_keepalive_time")
vs=("65536" "1024 65500" "1" "0" "600")

for ((i=0;i<${#ks[*]};i++))
do
    each=`cat /etc/sysctl.conf | grep "^${ks[i]}"`
    if [[ -z $each ]]
    then
        warn "未配置${ks[i]}, 进行配置..."
        echo "${ks[i]} = ${vs[i]}" >> /etc/sysctl.conf
    else
        v=`echo $each | awk -F ' *= *' '{printf("%s", $2)}'`
        debug "当前配置: $each 截取后: $v"
        if [ "$v" != "${vs[i]}" ]
        then
            warn "非规范配置, 进行更改..."
            #sed -n 's/^'${ks[i]}'.*/'${ks[i]}' = '${vs[i]}'/p' /etc/sysctl.conf
            sed -i "s/^${ks[i]}.*/${ks[i]} = ${vs[i]}/g" /etc/sysctl.conf
        fi
    fi
done
# 使配置生效
info "配置生效..."
sysctl -p

info "2. 系统打开文件数"
limit=`cat /etc/security/limits.conf | grep '^*\ *-\ *nofile\ *'`
if [[ -z $limit ]]
then
    warn "未配置, 进行配置..."
    echo "*  -  nofile  65536" >> /etc/security/limits.conf
else
    v=`echo "$limit" | awk '{printf("%s", $4)}'`
    debug "当前配置:" "$limit" "截取后: $v"
    if [ $v != "65536" ]
    then
        warn "非规范配置, 进行更改..."
        sed -i 's/^*\ *-\ *nofile.*/*  -  nofile  65536/g' /etc/security/limits.conf
    fi
fi

info "3. 系统连接数配置"
#*          soft    nproc     5120
#root       soft    nproc     unlimited
limit=`cat /etc/security/limits.d/*-nproc.conf | grep '^*\ *soft\ *nproc\ *'`
if [[ -z $limit ]]
then
    warn "未配置(*), 进行配置..."
    echo "*          soft    nproc     5120" >> /etc/security/limits.d/*-nproc.conf
else
    v=`echo "$limit" | awk '{printf("%s", $4)}'`
    debug "当前配置:" "$limit" "截取后: $v"
    if [ $v != "5120" ]
    then
        warn "非规范配置(5120), 进行更改..."
        sed -i 's/^*\ *soft\ *nproc.*/*          soft    nproc     5120/g' /etc/security/limits.d/*-nproc.conf
    fi
fi

limit=`cat /etc/security/limits.d/*-nproc.conf | grep '^root\ *soft\ *nproc\ *'`
if [[ -z $limit ]]
then
    warn "未配置(root), 进行配置..."
    echo "root       soft    nproc     unlimited" >> /etc/security/limits.d/*-nproc.conf
else
    v=`echo "$limit" | awk '{printf("%s", $4)}'`
    debug "当前配置: $limit 截取后: $v"
    if [ $v != "unlimited" ]
    then
        warn "非规范配置(unlimited), 进行更改..."
        sed -i 's/^root\ *soft\ *nproc.*/root       soft    nproc     unlimited/g' /etc/security/limits.d/*-nproc.conf
    fi
fi

printf "\n"

# 系统监控配置
# TODO

# 空口令检测
info "# 空口令检测"
awk -F: '($2 == "") {printf("%s\n", $1)}' /etc/shadow
printf "\n"

# UID为0账号检测
info "# UID为0账号检测"
awk -F: '($3 == 0) {printf("%s\n", $1)}' /etc/shadow
printf "\n"

# 超时注销配置
info "# 超时注销检测(/ect/profile)"
timeout=`cat /etc/profile | grep "^export TMOUT="`
if [[ -z $timeout ]]
then
    warn '未配置, 进行配置...'
    sed -i '$a export TMOUT=180' /etc/profile
    source /etc/profile
else
    v=`echo $timeout | awk -F= '{printf("%d", $2)}'`
    debug "当前配置: $timeout 截取后: $v"
    if [ $v -ne 180 ]
    then
        warn "非标准配置(180), 进行更改..."
        sed -i 's/^export TMOUT=.*/export TMOUT=180/g' /etc/profile
        source /etc/profile
    fi
fi
printf "\n"

# Root远程登录限制
# 注意：CONSOLE = /dev/tty01 中间可能有空格
info "# Root远程登录检测(/etc/securetty)"
console=`cat /etc/securetty | grep "^CONSOLE"`
if [[ -z $console ]]
then
    warn "未配置, 进行配置..."
    sed -i '$a CONSOLE = /dev/tty01' /etc/securetty
else
    v=`echo $console | sed 's/ //g' | awk -F= '{printf("%s", $2)}'`
    debug "当前配置: $console 截取后: $v"
    if [ $v != '/dev/tty01' ]
    then
        warn "非标准配置(/dev/tty01), 进行更改..."
        sed -i 's/^CONSOLE.*/CONSOLE = \/dev\/tty01/g' /etc/securetty
    fi
fi
printf "\n"

# 密码策略检测
info "# 密码策略检测(/etc/login.defs)"

ks=("PASS_MAX_DAYS" "PASS_MIN_LEN" "PASS_WARN_AGE")
vs=("90" "8" "10")

for ((i=0;i<${#ks[*]};i++))
do
    each=`cat /etc/login.defs | grep "^${ks[i]}"`
    if [[ -z $each ]]
    then
        warn "未配置${ks[i]}, 进行配置..."
        echo "${ks[i]} ${vs[i]}" >> /etc/login.defs
    else
        v=`echo $each | awk '{printf("%s", $2)}'`
        debug "当前配置: $each 截取后: $v"
        if [ "$v" != "${vs[i]}" ]
        then
            warn "非规范配置, 进行更改..."
            #sed -n "s/^${ks[i]}.*/${ks[i]} ${vs[i]}/p" /etc/login.defs
            sed -i "s/^${ks[i]}.*/${ks[i]} ${vs[i]}/g" /etc/login.defs
        fi
    fi
done

# OpenSSH 安全配置
info "# OpenSSH配置检测(/etc/ssh/sshd_config)"
ks=("Protocol" "StrictModes" "PermitRootLogin" "PrintLastLog" "PermitEmptyPasswords")
vs=("2" "yes" "no" "yes" "no")

for ((i=0;i<${#ks[*]};i++))
do
    each=`cat /etc/ssh/sshd_config | grep "^${ks[i]}"`
    if [[ -z $each ]]
    then
        warn "未配置${ks[i]}, 进行配置..."
        echo "${ks[i]} ${vs[i]}" >> /etc/ssh/sshd_config
        sshd_restart=1
    else
        v=`echo $each | awk '{printf("%s", $2)}'`
        debug "当前配置: $each 截取后: $v"
        if [ "$v" != "${vs[i]}" ]
        then
            warn "非规范配置, 进行更改..."
            #sed -n "s/^${ks[i]}.*/${ks[i]} ${vs[i]}/p" /etc/ssh/sshd_config
            sed -i "s/^${ks[i]}.*/${ks[i]} ${vs[i]}/g" /etc/ssh/sshd_config
            sshd_restart=1
        fi
    fi
done
printf "\n"

# root路径检测
info "# root环境变量检测"
if [[ -n `echo $PATH | grep ":\."` ]]
then
    warn "root环境变量path包含当前目录':.' :"$PATH
fi
printf "\n"

# 保留历史命令条数检测
info "# 保留历史命令条数检测(/etc/profile)"
histsize=`cat /etc/profile|grep HISTSZIE=`
if [[ -z $histsize ]]
then
    warn "没有配置: 'HISTSIZE'"
else
    echo "当前配置: $histsize"
fi
printf "\n"

# 磁盘剩余空间检测
info "# 磁盘剩余空间检测"
df -k | awk '(NR > 1 && $5 >= "80%"){printf("\033[31m%s\n\033[0m", $1)}'
printf "\n"

# 检查日志审核
info "# 检擦日志审核(/etc/rsyslog.conf)"
# centos7, centos6 /etc/rsyslog.conf
if [ -e '/etc/rsyslog.conf' ]
then
    authpriv=`cat /etc/rsyslog.conf | grep "^authpriv\.\*"`
    if [ -z "$authpriv" ]
    then
        echo "未开启日志审核, 进行配置..."
        sed -i '$a authpriv.*        /var/log/secure' /etc/rsyslog.conf
    else
        
        v=`echo $authpriv | awk '{printf("%s", $2)}'`
        debug "当前配置: $authpriv 截取后: $v"
        if [ $v != "/var/log/secure" ]
        then
            warn "非标准配置(/var/log/secure), 进行更改..."
            sed -i 's/^authpriv\.\*.*/authpriv\.\*     \/var\/log\/secure/g' /etc/rsyslog.conf
        fi
    fi
fi

# 相关服务重启
if [ $sshd_restart -eq 1 ]
then
    info "TODO 重启sshd服务..."
    #if [[ $version == 6 ]]
    #then
        #service sshd restart
    #elif [[ $version == 7 ]]
    #then
        #systemctl start sshd
    #fi    
fi