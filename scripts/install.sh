#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

[[ $EUID -ne 0 ]] && ${red}"非root权限\n"${plain} && exit 1

arch=$(uname -m)
system=$(uname)
country=''
appName='shy'

latestVersion=''
downloadPrefix='https://github.com/ppoonk/shy/releases/download/'
githubApi="https://api.github.com/repos/ppoonk/shy/releases/latest"
manageScript="https://raw.githubusercontent.com/ppoonk/shy/main/scripts/install.sh"
acmeGit="https://github.com/acmesh-official/acme.sh.git"



get_system_type(){
if [ "$system" == "Darwin" ]; then
  system="darwin-10.14"
else
  system="linux"
fi
}
get_arch(){
  if [[ $arch == "x86_64" || $arch == "x64" ]]; then
      arch="amd64"
  elif [[ $arch == "aarch64" || $arch == "arm64" || $arch == "armv8" || $arch == "armv8l" ]]; then
      arch="arm64"
  elif [[ $arch == "arm"  || $arch == "armv7" || $arch == "armv7l" || $arch == "armv6" ]];then
      arch="arm"
  else
      echo -e ${red}"不支持的arch，请自行编译\n"${plain}
      exit 1
  fi
}
get_region() {
    country=$( curl -4 "https://ipinfo.io/country" 2> /dev/null )
    if [ "$country" == "CN" ]; then
      acmeGit="https://gitee.com/neilpang/acme.sh.git"
      downloadPrefix="https://ghproxy.org/${downloadPrefix}"
      manageScript="https://ghproxy.org/${manageScript}"
    fi
}
open_ports(){
	systemctl stop firewalld.service >/dev/null 2>&1
	systemctl disable firewalld.service >/dev/null 2>&1
	setenforce 0 >/dev/null 2>&1
	ufw disable >/dev/null 2>&1
	iptables -P INPUT ACCEPT
	iptables -P FORWARD ACCEPT
	iptables -P OUTPUT ACCEPT
	iptables -t nat -F
	iptables -t mangle -F
	iptables -F
	iptables -X
}

set_dependences() {
    if [[ $(command -v yum) ]]; then
      if [[ ! $(command -v wget) ]] || [[ ! $(command -v curl) ]] || [[ ! $(command -v git) ]] || [[ ! $(command -v socat) ]] || [[ ! $(command -v unzip) ]] || [[ ! $(command -v gawk) ]] || [[ ! $(command -v lsof) ]]; then
          echo -e ${green}"安装依赖\n"${plain}
          yum update -y
          yum install wget curl git socat unzip gawk lsof -y
      fi
    elif [[ $(command -v apt) ]]; then
      if [[ ! $(command -v wget) ]] || [[ ! $(command -v curl) ]] || [[ ! $(command -v git) ]] || [[ ! $(command -v socat) ]] || [[ ! $(command -v unzip) ]] || [[ ! $(command -v gawk) ]] || [[ ! $(command -v lsof) ]]; then
          echo -e ${green}"安装依赖\n"${plain}
          apt update -y
          apt install wget curl git socat unzip gawk lsof -y
      fi
       echo -e "依赖已安装\n"
    fi
}
get_latest_version() {
          latestVersion=$(curl -Ls $githubApi | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
          if [[ ! -n "$latestVersion" ]]; then
              echo -e "${red}获取最新版本失败，请稍后重试${plain}"
              exit 1
          fi
}

initialize(){
  get_arch
  get_system_type
  set_dependences
  get_region
  get_latest_version

 ipv4=$(curl -4 -s --max-time 5 http://icanhazip.com/ || '你的ip' )
 #ipv6=$(curl -6 -s --max-time 5 http://icanhazip.com/)
 ipv4_local=$( ip addr | awk '/^[0-9]+: / {}; /inet.*global.*eth/ {print gensub(/(.*)\/(.*)/, "\\1", "g", $2)}' || '你的内网ip')

}
# example:  confirm_msg "确定要卸载吗?" "n"
confirm_msg() {
    if [[ $# -gt 1 ]]; then
        echo && read -p "$1 [y/n 默认$2]: " temp
        if [[ "${temp}x" == ""x ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ "${temp}"x == "y"x || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

# 安装检测，1：未安装 0：已安装
installation_status(){
      if [[ ! -f /etc/systemd/system/$1.service ]] || [[ ! -f /usr/local/$1/$1 ]]; then
        return 1
      else
        return 0
      fi
}
# 运行检测，1：未启动 0：已启动
run_status() {
      temp=$(systemctl is-active $1)
      if [[ x"${temp}" == x"active" ]]; then
          return 0
      else return 1
      fi
}

download(){
  echo -e "开始下载核心，版本：${latestVersion}"
  rm -rf /usr/local/${appName}
  mkdir /usr/local/${appName}

  wget -N --no-check-certificate -O /usr/bin/${appName} ${manageScript}
  chmod 777 /usr/bin/${appName}

#shy-0.0.1-linux-arm64.tar.gz
  wget -N --no-check-certificate -O /usr/local/${appName}/${appName}.tar.gz ${downloadPrefix}${latestVersion}/${appName}-${latestVersion}-${system}-${arch}.tar.gz
  if [[ $? -ne 0 ]]; then
      echo -e "${red}下载失败，请重试${plain}"
      exit 1
  fi
  echo -e "开始解压..."
  cd /usr/local/${appName}/
  tar -zxvf ${appName}.tar.gz
  chmod 777 -R /usr/local/${appName}

#  mv /usr/local/${appName}/${appName}-${system}-${arch} /usr/local/${appName}/${appName}

}
add_service(){
  cat >/etc/systemd/system/$1.service <<-EOF
  [Unit]
  Description=$1 Service
  After=network.target
  Wants=network.target
  StartLimitIntervalSec=0

  [Service]
  Restart=always
  RestartSec=1
  Type=simple
  WorkingDirectory=/usr/local/$1/
  ExecStart=/usr/local/$1/$1

  [Install]
  WantedBy=multi-user.target
EOF

}
install(){
  installation_status ${appName}
  if [[ $? -eq 0 ]]; then
      echo -e "${red}${appName}已安装${plain}"
      echo -n -e "${yellow}按回车返回主菜单: ${plain}" && read temp
      main
  fi
  run_status ${appName}
  if [[ $? -eq 0 ]]; then
   echo -e "${red}${appName}正在运行${plain}"
   echo -n -e "${yellow}按回车返回主菜单: ${plain}" && read temp
   main
  fi
  download
  add_service ${appName}
  systemctl daemon-reload
  systemctl enable ${appName}
  echo -e "${green}安装完成，版本：${latestVersion}${plain}"
  echo -n -e "${yellow}按回车返回主菜单: ${plain}" && read temp
  main
}
uninstall(){
  confirm_msg "确定要卸载吗?" "n"
      if [[ $? != 0 ]]; then
          return 0
      fi
  echo -e "开始卸载"
      systemctl stop ${appName}
      systemctl disable ${appName}
      systemctl daemon-reload
      systemctl reset-failed
      rm -rf /etc/systemd/system/${appName}.service /usr/local/${appName}

  echo -e "${green}卸载完成${plain}"
  echo
  echo -n -e "${yellow}按回车返回主菜单: ${plain}" && read temp
  main
}

start(){
  installation_status ${appName}
  if [[ $? -eq 1 ]]; then
      echo -e "${red}${appName}未安装${plain}"
      echo -n -e "${yellow}按回车返回主菜单: ${plain}" && read temp
      main
  fi

  run_status ${appName}
  if [[ $? -eq 0 ]]; then
   echo -e "${red}${appName}正在运行${plain}"
   echo -n -e "${yellow}按回车返回主菜单: ${plain}" && read temp
   main
  fi

  systemctl start ${appName}
  systemctl is-active ${appName}

  echo -e "${green}操作完成${plain}"
  echo -n -e "${yellow}按回车返回主菜单: ${plain}" && read temp
  main
}
stop(){
    installation_status ${appName}
    if [[ $? -eq 1 ]]; then
        echo -e "${red}${appName}未安装${plain}"
        echo -n -e "${yellow}按回车返回主菜单: ${plain}" && read temp
        main
    fi

    run_status ${appName}
    if [[ $? -eq 1 ]]; then
     echo -e "${red}${appName}未运行${plain}"
     echo -n -e "${yellow}按回车返回主菜单: ${plain}" && read temp
     main
    fi

  systemctl stop ${appName}
  systemctl is-active ${appName}
  echo -e "${green}操作完成${plain}"
  echo
  echo -n -e "${yellow}按回车返回主菜单: ${plain}" && read temp
  main
}
update(){
  confirm_msg "请务必做好数据备份！！！是否下载最新核心？" "n"
  if [[ $? != 0 ]]; then
      return 0
  fi
  cd /usr/local/${appName}

  echo -e "${yellow}正在更新管理脚本...${plain}"
  rm -rf /usr/bin/${appName}
  wget -N --no-check-certificate -O /usr/bin/${appName} ${manageScript}
  chmod 777 /usr/bin/${appName}

#  echo -e "${yellow}为防止关键数据丢失，正在备份原文件夹...${plain}"
#  date=$(date +%Y_%m_%d_%H_%M)
#  zip -rq ${date}.zip /usr/local/${appName}
#  echo -e "${yellow}原文件夹已备份为：${plain}AirGo_${date}.zip"
  echo -e "${yellow}正在下载版本：${plain}${latestVersion}"
  mkdir temp
  cd temp

    wget -N --no-check-certificate -O ${appName}.tar.gz ${downloadPrefix}${latestVersion}/${appName}-${latestVersion}-${system}-${arch}.tar.gz
    if [[ $? -ne 0 ]]; then
        echo -e "${red}下载失败，请重试${plain}"
        exit 1
    fi
    echo -e "开始解压..."

    tar -zxvf ${appName}.tar.gz
    chmod 777 *

    rm -rf /usr/local/${appName}/${appName}
    mv ${appName} /usr/local/${appName}/${appName}

    cd ..
    rm -rf temp

    systemctl stop ${appName}
    echo -e "${yellow}正在重启核心...${plain}"
    systemctl restart ${appName}
    systemctl status ${appName}
}


acme(){
  installation_status ${appName}
  if [[ $? -eq 1 ]]; then
      echo -e "${red}${appName}未安装${plain}"
      echo -n -e "${yellow}按回车返回主菜单: ${plain}" && read temp
      main
  fi

  installation_status ${appName}
  if [[ $? -ne 0 ]]; then
   echo -e "${red}${appName}未安装,脚本退出${plain}"
   exit 1
  fi
  cd /usr/local/${appName}
  if [[ ! -f /usr/local/${appName}/acme.sh/acme.sh ]];then
    git clone ${acmeGit}
    chmod 777 -R acme.sh
  fi
  cd acme.sh

  email=''
  domain=''

  echo -e "${yellow}设置Acme邮箱:${plain}"
  read -p "输入您的邮箱:" email
  echo -e "您的邮箱:${email}"

  echo -e "${yellow}设置域名:${plain}"
  read -p "输入您的域名:" domain
  echo -e "您的域名:${domain}"
  domainPrefix=$(echo ${domain%%.*})

  echo -e "${yellow}配置邮箱账户...${plain}"
  ./acme.sh --install -m ${email}
  echo -e "${yellow}正在发起 DNS 申请...${plain}"
  ./acme.sh --issue --dns -d ${domain} --yes-I-know-dns-manual-mode-enough-go-ahead-please

  echo -e "${yellow}请仔细查看命令行显示文本中，有无以下字段：${plain}"
  echo -e "[Tue Sep 12 12:30:59 UTC 2023] TXT value: '**************************************-****"

  echo -e "${yellow}如果存在该字段，请去你的域名 DNS 管理商，完成下面2个重要操作！！！${plain}"
  echo -e "${yellow}1、${plain}添加一个txt记录"
  echo -e "${yellow}2、${plain}将该记录的[名称]设置为：_acme-challenge.${domainPrefix}，完整域名为 _acme-challenge.${domain}"
  echo

  confirm_msg "是否已经添加这条 txt 记录？是否将该记录的[名称]设置为：_acme-challenge.${domainPrefix}？ "
   if [[ $? -ne 0 ]]; then
     echo -e "${red}未添加txt 记录,脚本退出${plain}"
     exit 1
   fi

  echo -e "${green}添加 txt 记录成功，进行下一步${plain}"
  echo -e "${green}开始申请证书...${plain}"

  ./acme.sh --renew -d ${domain} --yes-I-know-dns-manual-mode-enough-go-ahead-please
    if [ $? -ne 0 ]; then
        echo -e "${red}申请失败,脚本退出${plain}"
        exit 1
    fi
  echo -e "${green}申请成功,证书文件在/root/.acme.sh/${domain}文件夹下${plain}"
  echo -e "${green}正在将证书复制到/usr/local/${appName}/${plain}"

  cp /root/.acme.sh/${domain}*/fullchain.cer /usr/local/${appName}/${domain}.cer
  cp /root/.acme.sh/${domain}*/${domain}.key /usr/local/${appName}/${domain}.key

  echo -e "${green}操作完成，请修改配置文件中的证书路径!!!!并重启${plain}"
  echo -n -e "${yellow}按回车返回主菜单: ${plain}" && read temp
  main

}
main(){
  clear
  installationStatus='未安装'
  runStatus='未运行'
  installation_status ${appName}
  if [[ $? -eq 0 ]]; then
    installationStatus='已安装'
  fi
  run_status ${appName}
  if [[ $? == 0 ]]; then
    runStatus='已运行'
  fi

  echo -e "
  ${green}${appName}- 管理脚本${plain}
  状态： ${green}${installationStatus}${plain}    ${green}${runStatus}${plain}
  ${yellow}-------------------------${plain}
  ${green}1.${plain} 安装
  ${green}2.${plain} 卸载
  -${yellow}------------------------${plain}
  ${green}3.${plain} 启动
  ${green}4.${plain} 停止
  ${yellow}-------------------------${plain}

  ${green}6.${plain} 升级最新核心
  ${yellow}-------------------------${plain}
  ${green}7.${plain} 使用Acme脚本申请ssl证书
  (dns手动模式，无80和443端口也可申请证书)
  ${yellow}-------------------------${plain}
  ${green}8.${plain} 开放所有端口
  ${yellow}-------------------------${plain}
  ${green}0.${plain} 退出
 "

  echo && read -p "请输入序号: " tem
  case "${tem}" in
  1) install;;
  2) uninstall;;
  3) start;;
  4) stop;;
#  5) reset_admin;;
  6) update;;
  7) acme;;
  8) open_ports;;
  *) exit 0;;

  esac

}
initialize
main