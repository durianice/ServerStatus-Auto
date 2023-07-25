#!/bin/bash

WORKSPACE=/opt/ServerStatus
SERVICE_FILE="/etc/systemd/system/stat_client.service"
mkdir -p ${WORKSPACE}
cd ${WORKSPACE}

if ! [ -x "$(command -v unzip)" ]; then
  sudo apt install unzip -y
fi
if ! [ -x "$(command -v wget)" ]; then
  sudo apt install wget -y 
fi

OS_ARCH="$(uname -m)"
latest_version=$(curl -m 10 -sL "https://api.github.com/repos/zdz/ServerStatus-Rust/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
wget --no-check-certificate -qO "client-${OS_ARCH}-unknown-linux-musl.zip"  "https://github.com/zdz/ServerStatus-Rust/releases/download/${latest_version}/client-${OS_ARCH}-unknown-linux-musl.zip"
unzip -o "client-${OS_ARCH}-unknown-linux-musl.zip"

if [ -f "$SERVICE_FILE" ]; then
  systemctl stop stat_client
  systemctl disable stat_client
  rm -f ${SERVICE_FILE}
  systemctl daemon-reload
fi

read -rp "请输入上报地址(形如:http(s)://domain.com): " domain
if [[ -z $domain ]]; then
    echo "上报地址不能为空" && exit 1
fi
domain=$(echo "$domain" | tr '[:upper:]' '[:lower:]')
if [[ $domain =~ /$ ]]; then
    domain=${domain%?}
fi
re='^(https?)://([a-zA-Z0-9\u4e00-\u9fff_-]{1,63})(\.[a-zA-Z0-9-]{1,63})+(\.[a-zA-Z]{2,10})?(:[0-9]+)?$'
if [[ ! $domain =~ $re ]]; then
  echo "上报地址格式错误"
  exit 1
fi

cp stat_client.service ${SERVICE_FILE}
target="http://127.0.0.1:8080"
sed -i "s|$target|$domain|" ${SERVICE_FILE}
systemctl daemon-reload

# 启动
systemctl start stat_client
# 状态查看
systemctl status stat_client
# 使用以下命令开机自启
systemctl enable stat_client
# 停止
# systemctl stop stat_client