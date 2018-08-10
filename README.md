# centos-script.sh
 這是一個全自動設定 Centos7 的全自動懶人腳本。
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
