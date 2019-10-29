#!/bin/bash
echo "Checking for Bash version...."
echo "The Bash version is $BASH_VERSION !"
echo "Checking user ...."
[[ $EUID -ne 0 ]] && echo 'Error: This script must be run as root!' && exit 1

echo "Checking network connect...."
death=`ping www.hinet.net -c 5 | grep "packet loss" | awk '{print $4}'`
if (($death==0)) 
then {
echo "This is Program Require Network."
exit 1
}
fi

#
# ================================================================
# User VARIABLES
# ================================================================
ADD_USERNAME="qaz"         # 要自動新增的使用者(具有root權限)
ADD_USERPASS="123456"      # 自動新增的使用者密碼
HOSTNAME="localhost"       # 主機名稱
DB_USER="root"             # 資料庫帳號
DB_PASSWD="123456"         # 資料庫密碼
SSH_PORT="22"              # SSH 服務的 PORT 位
sEXTIF="enp0s3"             # 這個是可以連上 Public IP 的網路介面
sINIF=""                   # 內部 LAN 的連接介面；若無則寫成 INIF=""
sINNET="192.168.20.0/24"   # 若無內部網域介面，請填寫成 INNET=""，若有格式為 192.168.20.0/24
EXTNET="39.225.276.30"     # 外部IP位址
INSTALL_PHP="72"           # 7 or 71 or 72 or 73 or 74 ，不安裝的話 INSTALL_PHP=""
INSTALL_APACHE="YES"       # 要裝apache 設定 YES
INSTALL_NGINX="NO" 		   # 要裝 NGINX 設定 YES
FREETDS_IP="192.168.1.1" # MSSQL 的ip位址

custom_settings(){
# Custom Script 客製化想要新增的規則 
chmod +x /etc/rc.d/rc.local
cat >> /etc/rc.local <<EOT
/usr/local/virus/iptables/iptables.rule
# Add route table and EEP socker services.
route add -net 192.168.0.0 netmask 255.255.0.0 gw 192.168.20.254
socat TCP-LISTEN:4444,fork TCP:192.168.1.3:211 &
EOT
}
# ================================================================
# System VARIABLES
# ================================================================
WORK_FOLED=`pwd`
SCRIPT_FILE_NAME=`basename ${BASH_SOURCE[0]}`
SCRIPT_VERSION="0.1.0"
CENTOS_VER=`rpm -qi --whatprovides /etc/redhat-release | awk '/Version/ {print $3}' | awk 'BEGIN {FS="."}{print $1};'`
filename="${WORK_FOLED}/edpscript."$(date +"%Y-%m-%d")""
logfile="${filename}.log"
Black=`tput setaf 0`   #${Black}
Red=`tput setaf 1`     #${Red}
Green=`tput setaf 2`   #${Green}
Yellow=`tput setaf 3`  #${Yellow}
Blue=`tput setaf 4`    #${Blue}
Magenta=`tput setaf 5` #${Magenta}
Cyan=`tput setaf 6`    #${Cyan}
White=`tput setaf 7`   #${White}
Bold=`tput bold`       #${Bold}
Rev=`tput smso`        #${Rev}
Reset=`tput sgr0`      #${Reset}

log () {
# ================================================================
# Write log 
# ================================================================
    sleep 1 
    wdate=$(date +"%Y-%m-%d %H:%M:%S")	  
    echo -e "[ ${wdate} ] ${1}" \\n
    echo -e "[ ${wdate} ] ${1}" \\n >> $logfile  2>&1	
}

init() {
log "${Blue}add ${ADD_USERNAME} add ${Reset}"
useradd $ADD_USERNAME -g wheel
echo $ADD_USERNAME:$ADD_USERPASS | chpasswd

log "${Blue}限制只有 wheel 群組的使用者才能切換root${Reset}"
sed -i "6s:#auth:auth:g" /etc/pam.d/su
echo "SU_WHEEL_ONLY yes" >> /etc/login.defs

log "${Blue}自動釋放記憶體${Reset}"
echo 1 > /proc/sys/vm/drop_caches

log "${Blue}add repository${Reset}"
timedatectl set-timezone Asia/Taipei
dnf -y update
dnf -y upgrade
dnf -y install epel-release
dnf -y install elrepo-release
dnf -y install https://rpms.remirepo.net/enterprise/remi-release-8.rpm
dnf --enablerepo=remi-modular --disablerepo=AppStream module list 
# Initial Settings : Use Web Admin Console
systemctl enable --now cockpit.socket 
return 1
}
basesoftware(){
# ================================================================
# isntall base software and tools
# ================================================================
log "${Blue}安裝常用軟體與工具程式${Reset}"
dnf install -y htop net-tools wget unzip vim-enhanced p7zip p7zip-plugins screen telnet git gcc iptables-services ftp socat curl rkhunter golang traceroute device-mapper-persistent-data lvm2 python36 python36-devel python3-virtualenv augeas-libs
 
log "${Blue} chronyc Package 安裝中 ........... ${Reset}"
if [ -f /usr/sbin/chronyd ]; then
	echo "${Green}chronyc Package 已經安裝${Reset}" 
else
	dnf -y install chrony	
fi
	
if [ -f "/etc/chrony.conf" ]; then
	log "${Blue} 寫入 /etc/chrony.conf ........... ${Reset}"
	sed -i 's/server 0.centos.pool.ntp.org iburst/server tock.stdtime.gov.tw/g' /etc/chrony.conf
	sed -i 's/server 1.centos.pool.ntp.org iburst/server watch.stdtime.gov.tw/g' /etc/chrony.conf
	sed -i 's/server 2.centos.pool.ntp.org iburst/server time.stdtime.gov.tw/g' /etc/chrony.conf
	sed -i 's/server 3.centos.pool.ntp.org iburst/server clock.stdtime.gov.tw/g' /etc/chrony.conf
	sed -i 's/#allow 192.168.0.0\/16/allow 192.168.0.0\/16/g' /etc/chrony.conf	
fi
log "${Blue} 啟動chronyd並設定每次開機啟動 ........... ${Reset}"
systemctl enable --now chronyd	

log "${Blue} 安裝防毒軟體clamav  ${Reset}"
dnf --enablerepo=epel -y install clamav clamav-update

}

install_kernel () {
# ================================================================
# kernel update
# ================================================================
log "${Blue}Install Kernel Software${Reset}"
dnf --enablerepo=elrepo-kernel -y install kernel-ml
log "${Magenta}優化SSH設定${Reset}"
sed -i 's/^GSSAPIAuthentication yes$/GSSAPIAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config
sed -i 's/#Port 22/Port '$SSH_PORT'/' /etc/ssh/sshd_config
systemctl restart sshd >/dev/null 2>&1
echo "unset MAILCHECK" >> /etc/profile
log "${Magenta}Disable selinux${Reset}"
systemctl stop firewalld.service
systemctl disable firewalld.service
systemctl restart iptables.service
systemctl enable iptables.service
systemctl disable ip6tables.service
systemctl disable messagebus.service 
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
}

install_iptables() {
log "${Blue}開始安裝 iptable 防火牆...${Reset}"
mkdir -p /usr/local/virus
mkdir -p /usr/local/virus/iptables
log "${Blue}設定 spamhaus 機構的黑名單${Reset}"
cat >> /usr/local/virus/iptables/set_iptables_drop_lasso <<EOT
#!/bin/bash
#
# iptables 阻擋黑名單腳本
#
# 透過下載 http://www.spamhaus.org/drop/drop.lasso 提供的黑名單
# 產生一組專門阻擋的 chain，並建議使用 link (ln) 至 crond 來達成每日自動更新
#
PATH=/sbin:/bin:/usr/sbin:/usr/bin; export PATH
 
### 設定暫存檔與 drop.lasso url
 FILE="/tmp/drop.lasso"
 URL="http://www.spamhaus.org/drop/drop.lasso"
 CHAIN_NAME="DropList"
  
### 準備開始 ###
  echo ""
  echo "準備開始產生 $CHAIN_NAME chain 至 iptables 設定中"

   ### 下載 drop.lasso ###
   [ -f \$FILE ] && /bin/rm -f \$FILE || :
   cd /tmp
   wget \$URL
   blocks=\$(cat \$FILE  | egrep -v '^;' | awk '{ print \$1}')  
   ### 清空與產生 chain ###
    iptables -F \$CHAIN_NAME 2>/dev/null
    iptables -N \$CHAIN_NAME 2>/dev/null
     
### 放入規則 ###
for ipblock in \$blocks
	do
		iptables -A \$CHAIN_NAME -s \$ipblock -j DROP
	done
                      
### 刪除並放入主 chain 生效
	iptables -D INPUT   -j \$CHAIN_NAME 2>/dev/null
	iptables -D OUTPUT  -j \$CHAIN_NAME 2>/dev/null
	iptables -D FORWARD -j \$CHAIN_NAME 2>/dev/null
	iptables -I INPUT   -j \$CHAIN_NAME 2>/dev/null
	iptables -I OUTPUT  -j \$CHAIN_NAME 2>/dev/null
	iptables -I FORWARD -j \$CHAIN_NAME 2>/dev/null
                       
### 刪除暫存檔 ##
/bin/rm -f \$FILE
EOT
log "${Blue}設定 iptable 白名單 ${Reset}"
cat <<EOF > /usr/local/virus/iptables/iptables.allow
#!/bin/bash
# 底下填寫你允許進入本機的其他網域或主機
#iptables -A INPUT -i \$EXTIF -s \$INNET -j ACCEPT
iptables -A INPUT -i \$EXTIF -p tcp -m iprange  --src-range 149.154.167.197-149.154.167.233 --dport 1:65535 -j ACCEPT
EOF

log "${Blue}設定 iptable 黑名單 ${Reset}"
cat <<EOF > /usr/local/virus/iptables/iptables.deny
#!/bin/bash
# 底下填寫要封鎖本機的其他網域或主機
#iptables -A INPUT -i \$EXTIF -s 222.186.30.218/24 -j DROP
EOF

log "${Blue}設定 iptable 鳥哥的防火牆規則 ${Reset}"
cat <<EOF > /usr/local/virus/iptables/iptables.rule
#!/bin/bash

# 請先輸入您的相關參數，不要輸入錯誤了！
  EXTIF="$sEXTIF"             # 這個是可以連上 Public IP 的網路介面
  INIF="$sINIF"              # 內部 LAN 的連接介面；若無則寫成 INIF=""
  INNET="$sINNET" # 若無內部網域介面，請填寫成 INNET=""
  export EXTIF INIF INNET

# 第一部份，針對本機的防火牆設定！##########################################
# 1. 先設定好核心的網路功能：
  echo "1" > /proc/sys/net/ipv4/tcp_syncookies
  echo "1" > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts
  for i in /proc/sys/net/ipv4/conf/*/{rp_filter,log_martians}; do
        echo "0" > \$i
  done
  for i in /proc/sys/net/ipv4/conf/*/{accept_source_route,accept_redirects,\
send_redirects}; do
        echo "0" > \$i
  done

# 2. 清除規則、設定預設政策及開放 lo 與相關的設定值
  PATH=/sbin:/usr/sbin:/bin:/usr/bin:/usr/local/sbin:/usr/local/bin; export PATH
  iptables -F
  iptables -X
  iptables -Z
  iptables -P INPUT   DROP
  iptables -P OUTPUT  ACCEPT
  iptables -P FORWARD ACCEPT
# 允許本機和已經建立連線的封包通過 
  iptables -A INPUT -i lo -j ACCEPT
  iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# 3. 啟動額外的防火牆 script 模組
  if [ -f /usr/local/virus/iptables/iptables.deny ]; then
        sh /usr/local/virus/iptables/iptables.deny
  fi
  if [ -f /usr/local/virus/iptables/iptables.allow ]; then
        sh /usr/local/virus/iptables/iptables.allow
  fi
  if [ -f /usr/local/virus/iptables/iptables.http ]; then
        sh /usr/local/virus/iptables/iptables.http
  fi

# 4. 允許某些類型的 ICMP 封包進入
  AICMP="0 3 3/4 4 11 12 14 16 18"
  for tyicmp in \$AICMP
  do
    iptables -A INPUT -i \$EXTIF -p icmp --icmp-type \$tyicmp -j ACCEPT
  done

# 5. 允許某些服務的進入，請依照你自己的環境開啟
iptables -A INPUT -p TCP -i \$EXTIF --dport  21 --sport 1024:65534 -j ACCEPT # FTP
iptables -A INPUT -p TCP -i \$EXTIF --dport  $SSH_PORT --sport 1024:65534 -j ACCEPT # SSH
iptables -A INPUT -p TCP -i \$EXTIF --dport  25 --sport 1024:65534 -j ACCEPT # SMTP
iptables -A INPUT -p UDP -i \$EXTIF --dport  53 --sport 1024:65534 -j ACCEPT # DNS
iptables -A INPUT -p TCP -i \$EXTIF --dport  53 --sport 1024:65534 -j ACCEPT # DNS
iptables -A INPUT -p TCP -i \$EXTIF --dport  80 --sport 1024:65534 -j ACCEPT # WWW
iptables -A INPUT -p TCP -i \$EXTIF --dport 110 --sport 1024:65534 -j ACCEPT # POP3
iptables -A INPUT -p TCP -i \$EXTIF --dport 443 --sport 1:65534 -j ACCEPT # HTTPS
iptables -A INPUT -p TCP -i \$EXTIF --dport 3128 --sport 1024:65534 -j ACCEPT # PROXY 

iptables -A INPUT -p TCP -i \$EXTIF --dport  88 --sport 1:65534 -j ACCEPT # telegram
iptables -A INPUT -p TCP -i \$EXTIF --dport 6036 --sport 1024:65534 -j ACCEPT 
iptables -A INPUT -p TCP -i \$EXTIF --dport 8888 --sport 1024:65534 -j ACCEPT 
iptables -A INPUT -p TCP -i \$EXTIF --dport 8080 --sport 1024:65534 -j ACCEPT 
iptables -A INPUT -p TCP -i \$EXTIF --dport 4444 --sport 1:65534 -j ACCEPT # EEP 
iptables -A INPUT -p UDP -i \$EXTIF --dport 4444 --sport 1:65534 -j ACCEPT # EEP 
iptables -A INPUT -p TCP -i \$EXTIF --dport  8443 --sport 1:65534 -j ACCEPT # telegram

# 第二部份，針對後端主機的防火牆設定！###############################
# 1. 先載入一些有用的模組
  modules="ip_tables iptable_nat ip_nat_ftp ip_nat_irc ip_conntrack 
ip_conntrack_ftp ip_conntrack_irc"
  for mod in \$modules
  do
      testmod=\`lsmod | grep "^\${mod} " | awk '{print \$1}'\`
      if [ "\$testmod" == "" ]; then
            modprobe \$mod
      fi
  done

# 2. 清除 NAT table 的規則吧！
  iptables -F -t nat
  iptables -X -t nat
  iptables -Z -t nat
  iptables -t nat -P PREROUTING  ACCEPT
  iptables -t nat -P POSTROUTING ACCEPT
  iptables -t nat -P OUTPUT      ACCEPT

# 3. 若有內部介面的存在 (雙網卡) 開放成為路由器，且為 IP 分享器！
  if [ "\$INIF" != "" ]; then
    iptables -A INPUT -i \$INIF -j ACCEPT
    echo "1" > /proc/sys/net/ipv4/ip_forward
    if [ "\$INNET" != "" ]; then
        for innet in \$INNET
        do
            iptables -t nat -A POSTROUTING -s \$innet -o \$EXTIF -j MASQUERADE
        done
    fi
  fi

  # 如果你的 MSN 一直無法連線，或者是某些網站 OK 某些網站不 OK，
  # 可能是 MTU 的問題，那你可以將底下這一行給他取消註解來啟動 MTU 限制範圍
 iptables -A FORWARD -p tcp -m tcp --tcp-flags SYN,RST SYN -m tcpmss \
          --mss 1400:1536 -j TCPMSS --clamp-mss-to-pmtu

# 4. NAT 伺服器後端的 LAN 內對外之伺服器設定
iptables -t nat -A PREROUTING -p tcp -d 114.33.97.55 -m multiport --port 80,443 -j DNAT --to 168.95.1.1

# 5. 特殊的功能，包括 Windows 遠端桌面所產生的規則
# remote Camera
iptables -t nat -A PREROUTING -p tcp -d $EXTNET --dport 8888 -j DNAT --to 192.168.20.250:80
iptables -t nat -A PREROUTING -p tcp -d $EXTNET --dport 6036 -j DNAT --to 192.168.20.250:6036

# RDP Remote Desktop
iptables -t nat -A PREROUTING -p tcp -d $EXTNET --dport 30678 -j DNAT --to 192.168.20.8:3389
iptables -t nat -A PREROUTING -p tcp -d $EXTNET --dport 1007 -j DNAT --to 192.168.20.9:3389

# test db
iptables -t nat -A PREROUTING -p tcp -d $EXTNET --dport 4444 -j DNAT --to 192.168.20.8:211

#keefi RDP
iptables -A FORWARD -p tcp --dport 1007 -j ACCEPT
iptables -A FORWARD -p tcp --dport 4444 -j ACCEPT
iptables -A FORWARD -p tcp --dport 5466 -j ACCEPT
iptables -A FORWARD -p tcp --dport 12345 -j ACCEPT
#eric RDP
iptables -A FORWARD -p tcp --dport 30678 -j ACCEPT

#限制速度
iptables -A FORWARD -m limit -d 192.168.20.31 --limit 70/s --limit-burst 50 -j ACCEPT
iptables -A FORWARD -d 192.168.20.31 -j DROP
iptables -A FORWARD -m limit -s 192.168.20.31 --limit 70/s --limit-burst 50 -j ACCEPT
iptables -A FORWARD -s 192.168.20.31 -j DROP

# 6. 最終將這些功能儲存下來吧！
/sbin/service iptables save
EOF

chmod 755 -R /usr/local/virus/iptables/
log "${Blue}設定 每天更新 spamhaus 黑名單 ${Reset}"
ln -s /usr/local/virus/iptables/set_iptables_drop_lasso /etc/cron.daily
return 1
}

setsystem (){
log "${Blue} 優化網路卡設定 ${Reset}"
cat >> /etc/sysctl.conf <<EOT
net.ipv4.ip_forward = 1
net.ipv4.tcp_keepalive_time = 30
net.ipv4.tcp_syncookies = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_max_syn_backlog = 819200
net.ipv4.tcp_syncookies = 0
net.ipv4.tcp_tw_reuse = 1
net.core.default_qdisc=fq
net.core.rmem_default = 8388608
net.core.rmem_max = 16777216
net.core.wmem_default = 8388608
net.core.wmem_max = 16777216
net.core.netdev_max_backlog = 819200
net.core.somaxconn = 65535
kernel.shmmax = 17179869184
kernel.shmall = 4194304
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_synack_retries = 3
net.ipv4.tcp_syn_retries = 3
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_congestion_control = bbr
EOT
log "${Blue} 優化 vim 編輯器 ${Reset}"
cat >> /etc/vimrc <<EOT
set encoding=utf-8
set fileencodings=utf-8,cp950
syntax on
set nocompatible
set ai
set shiftwidth=4
set tabstop=4
set softtabstop=4
set expandtab
set number
set ruler
set backspace=2
set ic
set ru
set hlsearch
set incsearch
set smartindent
set confirm
set history=100
set cursorline
set laststatus=2
set statusline=%4*%<\%m%<[%f\%r%h%w]\ [%{&ff},%{&fileencoding},%Y]%=\[Position=%l,%v,%p%%]
colorscheme torte
EOT

log "${Blue}設定外部 GETWAY ${Reset}"
cat >> /etc/sysconfig/network <<EOT
NETWORKING=yes
NETWORKING_IPV6=no
GATEWAY=$EXTNET
EOT

log "${Blue}設定 Bash 終端機顏色 ${Reset}"  
cat >> /etc/bashrc <<EOT
PS1="\e[1;34m\u@\h \w> \e[m"
alias vi='vim'
alias ll='ls -al --color' 
setterm -blength 0
HISTTIMEFORMAT='%F %T '
EOT
#restart service
sysctl -p
chmod +x /etc/rc.d/rc.local

return 1
}

install_MariaDB () {
# ================================================================
# install_MariaDB
# ================================================================
log "${Blue}Install MariaDB 資料庫${Reset}"
cat >> /etc/yum.repos.d/MariaDB.repo <<EOT
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.4/centos8-amd64/
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOT
# 目前還不能使用 dnf 來安裝
#dnf -y --enablerepo=mariadb install mariadb-server
dnf -y install http://yum.mariadb.org/10.4/centos8-amd64/rpms/MariaDB-server-10.4.8-1.el8.x86_64.rpm
log "${Blue}Set MariaDB character utf8${Reset}"

sed -i '/\[mysql\]/a\default-character-set=utf8' /etc/my.cnf.d/mysql-clients.cnf
sed -i '/\[mysqld\]/a\character-set-server=utf8' /etc/my.cnf.d/server.cnf
sed -i '/\[mysqld\]/a\innodb_file_per_table = 1' /etc/my.cnf.d/server.cnf
sed -i '/\[mysqld\]/a\net_read_timeout=120' /etc/my.cnf.d/server.cnf
sed -i '/\[mysqld\]/a\event_scheduler = ON' /etc/my.cnf.d/server.cnf
sed -i '/\[mysqld\]/a\innodb_buffer_pool_size = 2G' /etc/my.cnf.d/server.cnf
sed -i '/\[mysqld\]/a\innodb_log_buffer_size =512M' /etc/my.cnf.d/server.cnf
sed -i '/\[mysqld\]/a\skip-name-resolve' /etc/my.cnf.d/server.cnf
sed -i '/\[mysqld\]/a\max_connections=100' /etc/my.cnf.d/server.cnf

log "${Blue}Install mydumper${Reset}"
dnf install -y https://github.com/maxbube/mydumper/releases/download/v0.9.5/mydumper-0.9.5-2.el7.x86_64.rpm

systemctl restart mariadb.service
systemctl enable mariadb.service
sleep 2
/usr/bin/mysqladmin -u root password $DB_PASSWD
return 1
}

install_apache() {
# ================================================================
# install apache
# ================================================================
if [ $INSTALL_APACHE = ""]; then
	log "${Blue} Apache Install abort. ${Reset}"	
	return 0
fi

log "${Blue}Install Apache${Reset}"

if [ -f "/usr/sbin/httpd" ]; then
	log "${Blue}httpd Package installed. ${Reset}"
else
	dnf -y install httpd
fi

sed -i '/#ServerName www.example.com:80/a\ServerName ${HOSTNAME}:80' /etc/httpd/conf/httpd.conf
sed -i '152s/AllowOverride None/AllowOverride All/g' /etc/httpd/conf/httpd.conf
sed -i '140,150s/Options Indexes FollowSymLinks/Options FollowSymLinks/g' /etc/httpd/conf/httpd.conf

sed -i '/LoadModule mpm_prefork_module modules\/mod_mpm_prefork.so/c\#LoadModule mpm_prefork_module modules\/mod_mpm_prefork.so'  /etc/httpd/conf.modules.d/00-mpm.conf
sed -i '/#LoadModule mpm_event_module modules\/mod_mpm_event.so/c\LoadModule mpm_event_module modules\/mod_mpm_event.so'  /etc/httpd/conf.modules.d/00-mpm.conf
log "${Blue}Change Apache modules [event_module]${Reset}"
cat >> /etc/httpd/conf.d/mpm.conf  <<EOT
<IfModule mpm_event_module>
ServerLimit           1000
StartServers             8
MinSpareThreads         75
MaxClients            1000
MaxSpareThreads        250
ThreadsPerChild         64
MaxRequestWorkers     2000
MaxConnectionsPerChild   2000
</IfModule>
EOT

cat >> /etc/httpd/conf/httpd.conf <<EOT
ServerTokens ProductOnly
KeepAlive ON
MaxKeepAliveRequests 0
ExtendedStatus Off
HostnameLookups off
KeepAliveTimeout 5
ServerSignature off 
EOT

echo Apache on RHEL 8 / CentOS 8 > /var/www/html/index.html

systemctl start httpd.service
systemctl enable httpd.service 

return 1
}

install_php(){
log "${Blue}Install PHP${Reset}"
dnf module install -y php:remi-7.3
log "${Blue}Install PHP Extesion ${Reset}"
dnf install -y php-fpm php-mysqlnd php-zip php-gd php-mcrypt php-mbstring php-curl php-xml php-pear php-bcmathphp-json php-cli php73-php-pdo* php-ctype php-openssl php-pdo php-tokenizer 

log "${Blue}Install Composer ${Reset}"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php --install-dir=/usr/local/bin --filename=composer

sed -i 's/\[egServer50\]/[SYBASE]/g' /etc/freetds.conf
sed -i 's/symachine.domain.com/'$FREETDS_IP'/g' /etc/freetds.conf
log "${Blue} Seting /etc/php.ini ............. ${Reset}"
sed -i '/date.timezone =/a\date.timezone = "Asia/Taipei"' /etc/php.ini
sed -i 's/expose_php = On/expose_php = Off/g' /etc/php.ini  
sed -i 's/short_open_tag = Off/short_open_tag = On/g' /etc/php.ini  
sed -i 's/display_errors = Off/display_errors = On/g' /etc/php.ini
sed -i 's/memory_limit = 128M/memory_limit = 768M/g' /etc/php.ini
sed -i 's/post_max_size = 8M/post_max_size = 500M/g' /etc/php.ini
sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 500M/g' /etc/php.ini  
systemctl restart httpd

}

install_vsftpd (){
if [ -f "/usr/sbin/vsftpd" ]; then
	log "${Blue} vsftpd Package installed. ${Reset}"
else
	 dnf -y install vsftpd
fi

sed -i 's/anonymous_enable=YES/anonymous_enable=No/g' /etc/vsftpd/vsftpd.conf
sed -i 's/#ascii_upload_enable=YES/ascii_upload_enable=YES/g' /etc/vsftpd/vsftpd.conf
sed -i 's/#ascii_download_enable=YES/ascii_download_enable=YES/g' /etc/vsftpd/vsftpd.conf
sed -i 's/#chroot_local_user=YES/chroot_local_user=YES/g' /etc/vsftpd/vsftpd.conf
sed -i 's/#chroot_list_enable=YES/chroot_list_enable=YES/g' /etc/vsftpd/vsftpd.conf
sed -i 's/#chroot_list_file=\/etc\/vsftpd\/chroot_list/chroot_list_file=\/etc\/vsftpd\/chroot_list/g' /etc/vsftpd/vsftpd.conf
sed -i 's/listen=NO/listen=YES/g' /etc/vsftpd/vsftpd.conf
sed -i 's/listen_ipv6=YES/listen_ipv6=NO/g' /etc/vsftpd/vsftpd.conf
sed -i 's/#ls_recurse_enable=YES/ls_recurse_enable=YES/g' /etc/vsftpd/vsftpd.conf

cat >> /etc/vsftpd/vsftpd.conf <<EOT
allow_writeable_chroot=YES
userlist_deny=NO
connect_from_port_20=NO
pasv_enable=YES
pasv_min_port=60101
pasv_max_port=60200

pam_service_name=vsftpd
userlist_enable=YES
EOT

echo 'vsftpd: ALL' >> /etc/hosts.deny
echo 'vsftpd:192.168.* 127.0.0.1' >> /etc/hosts.allow

touch /etc/vsftpd/chroot_list
chmod 644 /etc/vsftpd/chroot_list
echo $ADD_USERNAME >> /etc/vsftpd/chroot_list
echo $ADD_USERNAME >> /etc/vsftpd/user_list

systemctl restart vsftpd.service
systemctl enable vsftpd.service
return 1
}

install_squid (){
if [ -f "/usr/sbin/squid" ]; then
	log "${Blue} squid Package installed. ${Reset}"
else
	dnf -y install squid
fi
log "${Blue} 加入 proxy 網站白名單 ${Reset}"
touch /etc/squid/allowdomain.txt
chmod 644 /etc/squid/allowdomain.txt
cat >> /etc/squid/allowdomain.txt <<EOT
.taiwanbus.tw
.screenpresso.com
.solarbus.com.tw
.google.com
map.google.com
.microsoft.com
.microsoft.com.tw
.windowsupdate.com
.dyngate.com
.teamviewer.com
192.168.20
.msa.hinet.net
.googleapis.com
semantic-ui.com
.dropbox.com
cfl.dropboxstatic.com
168.95
line.
windowsupdate.microsoft.com
.update.microsoft.com
download.windowsupdate.com
redir.metaservices.microsoft.com
images.metaservices.microsoft.com
c.microsoft.com
www.download.windowsupdate.com
wustat.windows.com
crl.microsoft.com
sls.microsoft.com
productactivation.one.microsoft.com
ntservicepack.microsoft.com
.live.com
.digicert.com
.mp.microsoft.com
.cms.msn.com
EOT

touch /etc/squid/allowupdate.txt
chmod 644 /etc/squid/allowupdate.txt
cat >> /etc/squid/allowupdate.txt <<EOT
$sINNET
EOT
log "${Blue} 設定 proxy 使用者帳號密碼 ${Reset}"
sed -i '1a auth_param basic program /usr/lib64/squid/basic_ncsa_auth /etc/squid/squid_user.txt' /etc/squid/squid.conf
sed -i '2a auth_param basic children 5'  /etc/squid/squid.conf
sed -i '3a auth_param basic realm Welcome to $HOSTNAME proxy-only web server'  /etc/squid/squid.conf
 
systemctl restart squid
systemctl enable squid
return 1
}

install_letSSL(){
log "${Blue} 安裝 letsencrypt ... ${Reset}"
yum -y install gcc libffi-devel openssl-devel mod_ssl
mkdir /opt/letsencrypt
cd  /opt/letsencrypt
wget https://dl.eff.org/certbot-auto
chmod a+x certbot-auto
cat >> /etc/cron.daily/renew_letssl.sh  <<EOT
#!/bin/sh
/opt/letsencrypt/certbot-auto renew --quiet
EOT
# everday check let'ssl due date.
chmod +x /etc/cron.daily/renew_letssl.sh

return 1
}

final(){
clear
systemctl restart network >>/dev/null 2>&1
/usr/local/virus/iptables/iptables.rule >>/dev/null 2>&1
echo ""
echo "please reboot...."
echo "1. this is program use 'iptables -F' command clean all, please set iptable firewall rule,and edit file of /usr/local/virus/iptables/iptables.rule"
echo "2. run /opt/letsencrypt/certbot-auto, Setting SSL."
echo "3. rclone config, Setting Dropbox,GoogleDrive....."
return 1 
}  
 
# ================================================================
# Main
# ================================================================
log " Auto Install Centos8 Script Version ${SCRIPT_VERSION}"
echo -e \\n
localectl set-locale LANG=zh_TW.UTF-8
export PS1="\e[1;34m\u@\h \w> \e[m"
mkdir -v ${WORK_FOLED}/tmp  >> $logfile  2>&1


#初始化系統 
init
#安裝基本軟體
basesoftware
#安裝kernel
install_kernel 
#安裝 iptables
install_iptables
#優化環境設定
setsystem
#安裝 MariaDB
install_MariaDB 
#安裝 apache
install_apache 
#安裝 php
install_php
#安裝vsftpd
install_vsftpd
# 安裝proxy
install_squid
# 安裝 Let'SSL 免費憑證
install_letSSL
#custom_settings
final
# ================================================================
# END
# ================================================================
exit 0
