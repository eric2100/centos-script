# centos-script.sh
 這是一個全自動設定 Centos7 的全自動懶人腳本。
 在最新版的 CentOS-7-x86_64 1804 測試
# 執行前準備工作
* 下載 CentOS-7-x86_64-Minimal-1804.iso
* 安裝 centOS 並設定網卡IP，讓伺服器可以上網
* chmod +x centos-script.sh 讓他有執行權限
* 使用 root 最高權限管理員執行
# 他做了哪些事情
* 初始化系統:他會將環境設定成台灣時區，語言，並更新最新版的yum 倉儲。
* 安裝基本常用的網管軟體，像是 p7zip ftp screen telnet等等的。
* 將內建防火牆關閉，使用老牌 iptables 防火牆，設定檔案內容是 鳥哥 抄過來的，並稍微調整功能。
* 安裝 MariaDB 
* 安裝 apache
* 安裝 NGINX (測試功能 還沒完成，懶得換nginx)
* 安裝 PHP 可自選版本
* 安裝 vsftpd FTP Server
* 安裝 squid Proxy Server
* 安裝 letSSL
* 最後重開機後，完成。基本上跑完這個script 就是一台堪用的伺服器了。
# 使用方法
修改centos-script.sh 裡面的 User Variables相關設定

``` bash
ADD_USERNAME="qaz"         # 要自動新增的使用者(具有root權限)
ADD_USERPASS="123456"      # 自動新增的使用者密碼
HOSTNAME="localhost"       # 主機名稱
DB_USER="root"             # 資料庫帳號
DB_PASSWD="123456"         # 資料庫密碼
SSH_PORT="22"              # SSH 服務的 PORT 位
sEXTIF="ens33"             # 這個是可以連上 Public IP 的網路介面
sINIF=""                   # 內部 LAN 的連接介面；若無則寫成 INIF=""
sINNET="192.168.20.0/24"   # 若無內部網域介面，請填寫成 INNET=""，若有格式為 192.168.20.0/24
EXTNET="49.225.176.30"     # 外部IP位址
INSTALL_PHP="72"           # 5 or 7 or 71 or 72 ，不安裝的話 INSTALL_PHP=""
INSTALL_APACHE="YES"       # 要裝apache 設定 YES
INSTALL_NGINX="NO" 		   # 要裝 NGINX 設定 YES
FREETDS_IP="192.168.100.3" # MSSQL 的ip位址
# Custom Script 客製化想要新增的規則 
# Add route table and EEP socker services.
cat >> /etc/rc.local <<EOT
/usr/local/virus/iptables/iptables.rule
route add -net 192.168.0.0 netmask 255.255.0.0 gw 192.168.20.254
socat TCP-LISTEN:4444,fork TCP:192.168.1.3:211 &
EOT
```
