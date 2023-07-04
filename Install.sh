#!/bin/bash

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# 函数：打印错误消息并重新执行
print_error_and_retry() {
  echo -e "${RED}错误: $1${NC}"
  main_menu
}

# 函数：开启 BBR
enable_bbr() {
    if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
        echo "开启 BBR..."
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
        sysctl -p
        echo -e "${GREEN}BBR 已开启${NC}"
    else
        echo -e "${YELLOW}BBR 已经开启，跳过配置。${NC}"
    fi
}

# 函数：检查并安装 Go
install_go() {
    if ! command -v go &> /dev/null; then
        echo "下载并安装 Go..."
        local go_arch
        if [[ $(arch) == "x86_64" ]]; then
            go_arch="amd64"
        elif [[ $(arch) == "aarch64" ]]; then
            go_arch="arm64"
        else
            echo -e "${RED}不支持的架构: $(arch)${NC}"
            exit 1
        fi

        wget -c "https://go.dev/dl/go1.20.5.linux-$go_arch.tar.gz" -O - | tar -xz -C /usr/local
        echo 'export PATH=$PATH:/usr/local/go/bin' > /etc/profile
        source /etc/profile

        echo -e "${GREEN}Go 已安装${NC}"
    else
        echo -e "${YELLOW}Go 已经安装，跳过安装步骤。${NC}"
    fi
}

# 函数：下载和安装 Caddy
download_and_install_caddy() {
    local valid_option=false

    while [[ $valid_option == false ]]; do
        echo "选择 Caddy 的安装方式:"
        echo -e "  ${GREEN}[1]. 自行编译安装${NC}"
        echo -e "  ${GREEN}[2]. 下载预编译版本${NC}"
        read -p "请选择 [1-2]: " install_option

        case $install_option in
            1)
                install_go

                echo "正在编译安装 Caddy..."
                go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
                ~/go/bin/xcaddy build --with github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@naive
                setcap cap_net_bind_service=+ep ./caddy
                mv caddy /usr/bin/

                valid_option=true
                ;;
            2)
                local caddy_download_url=""
                if [[ $(arch) == "x86_64" ]]; then
                    caddy_download_url="https://github.com/TinrLin/NaiveProxy-installation/releases/download/2.6.4/caddy-linux-amd64.tar.gz"
                elif [[ $(arch) == "aarch64" ]]; then
                    caddy_download_url="https://github.com/TinrLin/NaiveProxy-installation/releases/download/2.6.4/caddy-linux-arm64.tar.gz"
                else
                    echo -e "${RED}不支持的架构: $(arch)${NC}"
                    exit 1
                fi

                echo "下载并安装 Caddy..."
                wget -c "$caddy_download_url" -O - | tar -xz -C /usr/bin
                chmod +x /usr/bin/caddy

                valid_option=true
                ;;
            *)
                echo -e "${RED}错误：无效的选项，请重新输入...${NC}"
                ;;
        esac
    done

    echo -e "${GREEN}Caddy 安装完成${NC}"
}


# 函数：检查防火墙配置
check_firewall_configuration() {
    if command -v ufw >/dev/null 2>&1; then
        echo "检查防火墙配置..."
        if ! ufw status | grep -q "Status: active"; then
            ufw enable
        fi

        if ! ufw status | grep -q " $listen_port"; then
            ufw allow "$listen_port"
        fi

        echo "防火墙配置已更新。"
    fi
}

# 函数：检查 Caddy 配置文件路径，如果不存在，则创建
check_create_config_path() {
    local config_path="/usr/local/etc/caddy"

    if [[ ! -d $config_path ]]; then
        mkdir -p "$config_path"
    fi
}

# 函数：获取用户输入的监听端口
get_listen_port() {
    local default_port=443

    while true; do
        read -p "请输入监听端口（默认: $default_port）: " listen_port

        if [[ -z $listen_port ]]; then
            # Use the default port if the user presses Enter without entering any value
            listen_port=$default_port
            break
        elif [[ $listen_port =~ ^[0-9]+$ ]]; then
            # Validate if the input is a valid port number
            if ((listen_port >= 1 && listen_port <= 65535)); then
                break
            else
                echo -e "${RED}无效的端口号，请重新输入。${NC}"
            fi
        else
            echo -e "${RED}无效的端口号，请重新输入。${NC}"
        fi
    done

    echo -e "监听端口: ${GREEN}$listen_port${NC}"
}  

# 函数：生成随机用户名
generate_auth_user() {
    read -p "请输入用户名（默认自动生成）: " user_input

    if [[ -z $user_input ]]; then
        auth_user=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)
    else
        auth_user=$user_input
    fi

    echo -e "用户名: ${GREEN}$auth_user${NC}"
}


# 函数：生成随机密码
generate_auth_pass() {
    read -p "请输入密码（默认自动生成）: " pass_input

    if [[ -z $pass_input ]]; then
        auth_pass=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
    else
        auth_pass=$pass_input
    fi

    echo -e "密码: ${GREEN}$auth_pass${NC}"
}


# 函数：获取用户输入的伪装网址
get_fake_site() {
    while true; do
        read -p "请输入伪装网址（默认: www.fan-2000.com）: " fake_site
        fake_site=${fake_site:-"www.fan-2000.com"}

        # Validate the fake site URL
        if curl --output /dev/null --silent --head --fail "$fake_site"; then
            echo -e "${GREEN}伪装网址: $fake_site${NC}"
            break
        else
            echo -e "${RED}伪装网址无效或不可用，请重新输入。${NC}"
        fi
    done
}


# 函数：获取用户输入的域名，如果域名未绑定本机 IP，则要求重新输入
get_domain() {
    read -p "请输入域名（用于自动申请证书）: " domain
    while true; do
        if [[ -z $domain ]]; then
            echo -e "${RED}域名不能为空，请重新输入。${NC}"
        else
            if ping -c 1 $domain >/dev/null 2>&1; then
                break
            else
                echo -e "${RED}域名未绑定本机 IP，请重新输入。${NC}"
            fi
        fi
        read -p "请输入域名（用于自动申请证书）: " domain
    done

    echo -e "域名: ${GREEN}$domain${NC}"
}

# 函数：创建 Caddy 配置文件
create_caddy_config() {
    local config_path="/usr/local/etc/caddy"
    local config_file="$config_path/caddy.json"

    echo "检查 Caddy 配置文件..."
    check_create_config_path

    if [[ ! -f $config_file ]]; then
        echo "创建 Caddy 配置文件..."

        get_listen_port
        generate_auth_user
        generate_auth_pass
        get_fake_site
        get_domain

        local caddy_config='{
  "apps": {
    "http": {
      "servers": {
        "https": {
          "listen": [":'$listen_port'"],
          "routes": [
            {
              "handle": [
                {
                  "handler": "forward_proxy",
                  "auth_user_deprecated": "'$auth_user'",
                  "auth_pass_deprecated": "'$auth_pass'",
                  "hide_ip": true,
                  "hide_via": true,
                  "probe_resistance": {}
                }
              ]
            },
            {
              "handle": [
                {
                  "handler": "headers",
                  "response": {
                    "set": {
                      "Strict-Transport-Security": ["max-age=31536000; includeSubDomains; preload"]
                    }
                  }
                },
                {
                  "handler": "reverse_proxy",
                  "headers": {
                    "request": {
                      "set": {
                        "Host": [
                          "{http.reverse_proxy.upstream.hostport}"
                        ],
                        "X-Forwarded-Host": ["{http.request.host}"]
                      }
                    }
                  },
                  "transport": {
                    "protocol": "http",
                    "tls": {}
                  },
                  "upstreams": [
                    {"dial": "'$fake_site':443"}
                  ]
                }
              ]
            }
          ],
          "tls_connection_policies": [
            {
              "match": {
                "sni": ["'$domain'"]
              },
              "protocol_min": "tls1.2",
              "protocol_max": "tls1.2",
              "cipher_suites": ["TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256"],
              "curves": ["secp521r1","secp384r1","secp256r1"]
            }
          ],
          "protocols": ["h1","h2"]
        }
      }
    },
    "tls": {
      "certificates": {
        "automate": ["'$domain'"]
      },
      "automation": {
        "policies": [
          {
            "issuers": [
              {
                "module": "acme"
              }
            ]
          }
        ]
      }
    }
  }
}'

        echo "$caddy_config" >"$config_file"
        echo "Caddy 配置文件已创建。"
    else
        echo "Caddy 配置文件已存在，重新配置..."

        get_listen_port
        generate_auth_user
        generate_auth_pass
        get_fake_site
        get_domain

        # 更新配置文件中的客户配置信息
        sed -i 's/"listen": \[":.*"\]/"listen": [":'$listen_port'"]/g' "$config_file"
        sed -i 's/"auth_user_deprecated": ".*"/"auth_user_deprecated": "'$auth_user'"/g' "$config_file"
        sed -i 's/"auth_pass_deprecated": ".*"/"auth_pass_deprecated": "'$auth_pass'"/g' "$config_file"
        sed -i 's/"dial": ".*"/"dial": "'$fake_site':443"/g' "$config_file"
        sed -i 's/"sni": \[".*"\]/"sni": ["'$domain'"]/g' "$config_file"

        echo "Caddy 配置文件已更新。"
    fi
}


test_caddy_config() {
    echo "测试 Caddy 配置是否正确..."
    local output
    local caddy_pid

    # 运行Caddy并捕获输出
    output=$(timeout 10 /usr/bin/caddy run --environ --config /usr/local/etc/caddy/caddy.json 2>&1 &)
    caddy_pid=$!

    # 等待Caddy进程完成或超时
    wait $caddy_pid 2>/dev/null

    # 检查输出中是否包含错误提示
    if echo "$output" | grep -qi "error"; then
        echo -e "${RED}Caddy 配置测试未通过，请检查配置文件${NC}"
        echo "$output"  # 输出错误信息
    else
        echo -e "${GREEN}Caddy 配置测试通过${NC}"
    fi
}





# 函数：配置 Caddy 自启动服务
configure_caddy_service() {
    echo "配置 Caddy 自启动服务..."
    local service_file="/etc/systemd/system/caddy.service"

    if [[ -f $service_file ]]; then
        echo "Caddy 服务文件已存在，重新写入配置..."
        rm "$service_file"
    fi

        local service_config='[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
ExecStart=/usr/bin/caddy run --environ --config /usr/local/etc/caddy/caddy.json
ExecReload=/usr/bin/caddy reload --config /usr/local/etc/caddy/caddy.json
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target'

        echo "$service_config" >"$service_file"
        systemctl daemon-reload
        systemctl enable caddy
        systemctl start caddy
        systemctl reload caddy
        echo "Caddy 自启动服务已配置。"
}

# 函数：安装 NaiveProxy
install_naiveproxy() {
    echo -e "${GREEN}------------------------ 安装 NaiveProxy ------------------------${NC}"
    
    # 开启 BBR
    enable_bbr
    
    # 下载和安装 Caddy
    download_and_install_caddy    
    
    # 创建 Caddy 配置文件
    create_caddy_config

    # 检查防火墙配置
    check_firewall_configuration  
     
    # 测试 Caddy 配置是否正确
    test_caddy_config
    
    # 配置 Caddy 自启动服务
    configure_caddy_service
    
    echo -e "${GREEN}------------------------ NaiveProxy 安装完成 ------------------------${NC}"
    
    echo -e "${GREEN}NaiveProxy节点配置信息:${NC}"
    echo -e "监听端口: ${GREEN}$listen_port${NC}"
    echo -e "用 户 名: ${GREEN}$auth_user${NC}"
    echo -e "密    码: ${GREEN}$auth_pass${NC}"
    echo -e "域    名: ${GREEN}$domain${NC}"   
}

# 函数：重启 NaiveProxy
restart_naiveproxy() {
    echo -e "${GREEN}--- 重启 NaiveProxy ---${NC}"
    systemctl restart caddy
    echo -e "${GREEN}--- NaiveProxy 已重启 ---${NC}"
}

# 函数：查看 NaiveProxy 运行状态
check_naiveproxy_status() {
    echo -e "${GREEN}--- NaiveProxy 运行状态 ---${NC}"
    systemctl status caddy
}

# 函数：停止 NaiveProxy
stop_naiveproxy() {
    echo -e "${GREEN}--- 停止 NaiveProxy ---${NC}"
    systemctl stop caddy
    echo -e "${GREEN}--- NaiveProxy 已停止 ---${NC}"
}

# 函数：卸载 NaiveProxy
uninstall_naiveproxy() {
    echo -e "${GREEN}--- 卸载 NaiveProxy ---${NC}"
    systemctl stop caddy
    systemctl disable caddy
    rm /etc/systemd/system/caddy.service
    rm /usr/local/etc/caddy/caddy.json
    rm /usr/bin/caddy
    echo -e "${GREEN}--- NaiveProxy 已卸载 ---${NC}"
}

# 函数：主菜单选项
main_menu() {
echo -e "${GREEN}               ------------------------------------------------------------------------------------ ${NC}"
echo -e "${GREEN}               |                          欢迎使用NaiveProxy 安装程序                             |${NC}"
echo -e "${GREEN}               |                      项目地址:https://github.com/TinrLin                         |${NC}"
echo -e "${GREEN}               ------------------------------------------------------------------------------------${NC}"        
  echo -e "请选择要执行的操作:"
  echo -e "  ${GREEN}[1]. 安装 NaiveProxy${NC}"
  echo -e "  ${GREEN}[2]. 重启 NaiveProxy${NC}"
  echo -e "  ${GREEN}[3]. 查看 NaiveProxy 运行状态${NC}"
  echo -e "  ${GREEN}[4]. 停止 NaiveProxy${NC}"
  echo -e "  ${GREEN}[5]. 卸载 NaiveProxy${NC}"
  echo -e "  ${GREEN}[0]. 退出${NC}"

  read -p "请输入: " choice

  case $choice in
    1)
      install_naiveproxy
      ;;
    2)
      restart_naiveproxy
      ;;
    3)
      check_naiveproxy_status
      ;;
    4)
      stop_naiveproxy
      ;;
    5)
      uninstall_naiveproxy
      ;;
    0)
      exit 0
      ;;
    *)
      print_error_and_retry "无效的选项，请重新输入..."
      ;;
  esac
}

main_menu
