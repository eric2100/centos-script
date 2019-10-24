#!/bin/bash
echo "Checking for Bash version...."
echo "The Bash version is $BASH_VERSION !"
# Check User 
[[ $EUID -ne 0 ]] && echo 'Error: This script must be run as root!' && exit 1

# Check Network 
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
dnf install -y htop net-tools wget unzip vim-enhanced p7zip p7zip-plugins screen telnet git gcc iptables-services ftp socat curl rkhunter golang traceroute device-mapper-persistent-data lvm2
 
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

}

final(){
clear
systemctl restart network >>/dev/null 2>&1
#/usr/local/virus/iptables/iptables.rule >>/dev/null 2>&1
echo ""
echo "please reboot...."
echo "1. run /opt/letsencrypt/certbot-auto, Setting SSL."
echo "2. rclone config, Setting Dropbox,GoogleDrive....."
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
#basesoftware

#custom_settings
final
# ================================================================
# END
# ================================================================
exit 0
