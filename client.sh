#!/bin/bash

WORKSPACE=/opt/ServerStatus
SERVICE_FILE="/etc/systemd/system/stat_client.service"
mkdir -p ${WORKSPACE}
cd ${WORKSPACE}

if ! [ -x "$(command -v unzip)" ]; then
  sudo apt-get install unzip -y
fi
if ! [ -x "$(command -v wget)" ]; then
  sudo apt-get install wget -y 
fi

if ! [ -x "$(command -v awk)" ]; then
  sudo apt-get install wak -y 
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
#re='^(https?)://([a-zA-Z0-9\u4e00-\u9fff_-]{1,63})(\.[a-zA-Z0-9-]{1,63})+(\.[a-zA-Z]{2,10})?(:[0-9]+)?$'
#if [[ ! $domain =~ $re ]]; then
#  echo "上报地址格式错误"
#  exit 1
#fi

read -rp "请输入服务端预设组标识: " gid
if [[ -z $gid ]]; then
    echo "标识不能为空" && exit 1
fi

read -rp "请输入对应密码: " pwd
if [[ -z $pwd ]]; then
    echo "密码不能为空" && exit 1
fi

read -rp "请输入备注(回车默认): " name
if [[ -z $name ]]; then
    name=$(cat /etc/hostname)
fi

cat > ${SERVICE_FILE} << EOF
  [Unit]
  Description=ServerStatus-Rust Client
  After=network.target
  
  [Service]
  User=root
  Group=root
  Environment="RUST_BACKTRACE=1"
  WorkingDirectory=/opt/ServerStatus
  # EnvironmentFile=/opt/ServerStatus/.env
  ExecStart=/opt/ServerStatus/stat_client -a "${domain}/report" -g ${gid} -p ${pwd} --alias ${name}
  ExecReload=/bin/kill -HUP $MAINPID
  Restart=on-failure
  
  [Install]
  WantedBy=multi-user.target
  
  # /etc/systemd/system/stat_client.service
  # journalctl -u stat_client -f -n 100
EOF
systemctl daemon-reload

# 启动
systemctl start stat_client
# 状态查看
systemctl status stat_client
# 使用以下命令开机自启
systemctl enable stat_client
# 停止
# systemctl stop stat_client
