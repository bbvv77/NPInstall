#!/bin/bash

# 更新软件源及安装组件
echo "更新软件源..."
apt update && apt -y install wget

# 开启 BBR
echo "开启 BBR..."
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

echo "BBR 已开启"

# 选择 Caddy 安装方式
caddy_install_option=""

while [[ $caddy_install_option != "1" && $caddy_install_option != "2" ]]; do
    read -p $'\e[36m请选择 Caddy 的安装方式 
1.自行编译
2.下载已编译的caddy
请选择 [1/2]: \e[0m' caddy_install_option

    if [[ $caddy_install_option != "1" && $caddy_install_option != "2" ]]; then
        echo -e "\e[31m无效的选择，请重新输入。\e[0m"
    fi
done

if [[ $caddy_install_option == "1" ]]; then
    # 自行编译 Caddy
    echo "下载并安装 Go..."
    if [[ $(arch) == "x86_64" ]]; then
        wget -c https://go.dev/dl/go1.20.5.linux-amd64.tar.gz -O - | tar -xz -C /usr/local 
    elif [[ $(arch) == "aarch64" ]]; then
        wget -c https://go.dev/dl/go1.20.5.linux-arm64.tar.gz -O - | tar -xz -C /usr/local 
    else
        echo "不支持的架构: $(arch)"
        exit 1
    fi

    echo 'export PATH=$PATH:/usr/local/go/bin' > /etc/profile
    source /etc/profile

    echo "编译安装 Caddy..."
    go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
    ~/go/bin/xcaddy build --output caddy --with github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@naive
    setcap cap_net_bind_service=+ep ./caddy
    chmod +x caddy
    mv caddy /usr/bin/

elif [[ $caddy_install_option == "2" ]]; then
    # 下载已编译的 Caddy
    if [[ $(arch) == "x86_64" ]]; then
        echo "下载并安装预编译的 Caddy (AMD 内核)..."
        wget -c https://github.com/TinrLin/NaiveProxy-installation/releases/download/2.6.4/caddy-linux-amd64.tar.gz -O - | tar -xz -C /usr/bin
    elif [[ $(arch) == "aarch64" ]]; then
        echo "下载并安装预编译的 Caddy (ARM 内核)..."
        wget -c https://github.com/TinrLin/NaiveProxy-installation/releases/download/2.6.4/caddy-linux-arm64.tar.gz -O - | tar -xz -C /usr/bin
    else
        echo "不支持的架构: $(arch)"
        exit 1
    fi
    
    chmod +x /usr/bin/caddy
    
fi

# 创建 Caddy 配置文件
echo "创建 Caddy 配置文件..."
mkdir -p /usr/local/etc/caddy
config_file="/usr/local/etc/caddy/caddy.json"

# 监听端口
while true; do
    read -p $'\e[36m请输入监听端口（默认为443）：\e[0m' listen_port
    listen_port=${listen_port:-443}

    # 验证端口范围
    if (( listen_port < 1 || listen_port > 65535 )); then
        echo -e "\e[31m端口范围为1-65535！请重新输入。 \e[0m"
    else
        break
    fi
done

# 用户配置信息
config_content=""

# 添加默认用户配置
default_user=""
read -p $'\e[36m请输入用户名（回车将随机生成）：\e[0m' default_user
default_user=${default_user:-$(openssl rand -base64 8)}
echo -e "\e[36m用户名: $default_user\e[0m"

default_password=""
read -p $'\e[36m密码（回车将随机生成）：\e[0m' default_password
default_password=${default_password:-$(openssl rand -base64 8)}
echo -e "\e[36m密码: $default_password\e[0m"

config_content+="            {
              \"handle\": [
                {
                  \"handler\": \"forward_proxy\",
                  \"auth_user_deprecated\": \"$default_user\",
                  \"auth_pass_deprecated\": \"$default_password\",
                  \"hide_ip\": true,
                  \"hide_via\": true,
                  \"probe_resistance\": {}
                }
              ]
            },"

# 添加多用户配置
add_more_users=""
while [[ $add_more_users != "n" && $add_more_users != "N" ]]; do
    read -p $'\e[36m是否添加多用户配置？(y/n): \e[0m' add_more_users

    if [[ $add_more_users == "y" || $add_more_users == "Y" ]]; then
        user=""
        read -p $'\e[36m请输入用户名（回车将随机生成）：\e[0m' user
        user=${user:-$(openssl rand -base64 8)}
        echo -e "\e[36m用户名: $user\e[0m"

        password=""
        read -p $'\e[36m请输入密码（回车将随机生成）：\e[0m' password
        password=${password:-$(openssl rand -base64 8)}
        echo -e "\e[36m密码: $password\e[0m"

        config_content+="
            {
              \"handle\": [
                {
                  \"handler\": \"forward_proxy\",
                  \"auth_user_deprecated\": \"$user\",
                  \"auth_pass_deprecated\": \"$password\",
                  \"hide_ip\": true,
                  \"hide_via\": true,
                  \"probe_resistance\": {}
                }
              ]
            },"
    fi
done

# 伪装网址
proxy_domain=""
while true; do
    read -p $'\e[36m请输入伪装网址（默认为www.fan-2000.com）：\e[0m' proxy_domain
    proxy_domain=${proxy_domain:-"www.fan-2000.com"}

    # 验证伪装网址的可访问性
    if ! ping -c 1 $proxy_domain &> /dev/null && ! curl --head --silent --fail "https://$proxy_domain" &> /dev/null; then
        echo -e "\e[31m错误：伪装网址无法访问或不是 HTTPS 网站，请重新输入。\e[0m"
    else
        break
    fi
done

# 域名配置
domain=""
while [[ -z $domain ]]; do
    read -p $'\e[36m请输入您的域名：\e[0m' domain

    # 检查域名是否解析到本机IP
    ip=$(curl -s http://checkip.amazonaws.com)
    resolved_ip=$(dig +short $domain)

    if [[ $ip != $resolved_ip ]]; then
        echo -e "\e[31m错误：域名解析失败，请确保域名解析到本机IP！\e[0m"
    else
        break
    fi
done

# 移除最后一个逗号
config_content="${config_content%,}"

# 生成最终配置文件内容
final_config="{
  \"apps\": {
    \"http\": {
      \"servers\": {
        \"https\": {
          \"listen\": [\":$listen_port\"],
          \"routes\": [
            {
              \"handle\": [
                {
                  \"handler\": \"reverse_proxy\",
                  \"headers\": {
                    \"request\": {
                      \"set\": {
                        \"Host\": [
                          \"{http.reverse_proxy.upstream.hostport}\"
                        ],
                        \"X-Forwarded-Host\": [\"{http.request.host}\"]
                      }
                    }
                  },
                  \"transport\": {
                    \"protocol\": \"http\",
                    \"tls\": {}
                  },
                  \"upstreams\": [
                    {\"dial\": \"$proxy_domain:443\"}
                  ]
                }
              ]
            },
$config_content
          ],
          \"tls_connection_policies\": [
            {
              \"match\": {
                \"sni\": [\"$domain\"]
              },
              \"protocol_min\": \"tls1.2\",
              \"protocol_max\": \"tls1.2\",
              \"cipher_suites\": [\"TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256\"],
              \"curves\": [\"secp521r1\",\"secp384r1\",\"secp256r1\"]
            }
          ],
          \"protocols\": [\"h1\",\"h2\"]
        }
      }
    },
    \"tls\": {
      \"certificates\": {
        \"automate\": [\"$domain\"]
      },
      \"automation\": {
        \"policies\": [
          {
            \"issuers\": [
              {
                \"module\": \"acme\"
              }
            ]
          }
        ]
      }
    }
  }
}" >> "$config_file"

echo "Caddy 配置文件创建完成。"

# 检查防火墙配置
if command -v ufw >/dev/null 2>&1; then
    echo "检查防火墙配置..."
    if ! ufw status | grep -q "Status: active"; then
        ufw enable
    fi

    if ! ufw status | grep -q " $listen_port/tcp"; then
        ufw allow "$listen_port"/tcp
    fi

    if ! ufw status | grep -q " 80/tcp"; then
        ufw allow 80/tcp
    fi

    echo "防火墙配置已更新。"
fi

# 后台运行 Caddy
echo "运行 Caddy..."
/usr/bin/caddy start --config $config_file

为 caddy 创建唯一的 Linux 组和用户
echo "创建 Caddy 的 Linux 组和用户"
groupadd --system caddy
useradd --system \
--gid caddy \
--create-home \
--home-dir /var/lib/caddy \
--shell /usr/sbin/nologin \
--comment "Caddy web server" \
caddy

# 创建 Caddy systemd 服务
echo "创建 Caddy systemd 服务..."
echo "[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
ExecStart=/usr/bin/caddy run --environ --config $config_file
ExecReload=/usr/bin/caddy reload --config $config_file
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/caddy.service

# 启动 Caddy
echo "重新加载守护进程并启动 Caddy..."
systemctl daemon-reload
systemctl enable caddy
systemctl start caddy

echo "Caddy 安装和配置完成。"

echo -e "\e[36m节点配置信息:\e[0m"
echo -e "\e[36m域名: $domain\e[0m"
echo -e "\e[36m监听端口: $listen_port\e[0m"

while IFS= read -r line; do
    if [[ $line =~ "auth_user_deprecated" ]]; then
        user=$(echo "$line" | awk -F'"' '{print $4}')
    elif [[ $line =~ "auth_pass_deprecated" ]]; then
        password=$(echo "$line" | awk -F'"' '{print $4}')
        echo -e "\e[36m用户名: $user / 密码: $password\e[0m"
    fi
done <<< "$config_content"
