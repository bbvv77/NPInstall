# **安装**
### 安装go

- **Linux AMD64**
```
apt -y update && apt -y install wget socat curl && wget -c https://go.dev/dl/go1.21.1.linux-amd64.tar.gz -O - | tar -xz -C /usr/local && echo 'export PATH=$PATH:/usr/local/go/bin' > /etc/profile && source /etc/profile && go version 
```
- **Linux ARM64**
```
apt -y update && apt -y install wget socat curl && wget -c https://go.dev/dl/go1.21.1.linux-arm64.tar.gz -O - | tar -xz -C /usr/local && echo 'export PATH=$PATH:/usr/local/go/bin' > /etc/profile && source /etc/profile && go version 
```
### 编译安装Caddy
```
go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest && ~/go/bin/xcaddy build --output caddy --with github.com/mholt/caddy-l4 --with github.com/caddy-dns/cloudflare --with github.com/caddy-dns/duckdns --with github.com/mholt/caddy-dynamicdns --with github.com/mholt/caddy-events-exec --with github.com/WeidiDeng/caddy-cloudflare-ip --with github.com/mholt/caddy-webdav --with github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@naive && setcap cap_net_bind_service=+ep ./caddy && chmod +x caddy && mv caddy /usr/bin/
```
### 配置Caddy开机自启服务
```
wget -P /etc/systemd/system https://raw.githubusercontent.com/TinrLin/NaiveProxy-installation/main/caddy.service
```
### 下载并修改Caddy配置文件（443端口）
```
wget -O /usr/local/etc/caddy.json https://raw.githubusercontent.com/TinrLin/NaiveProxy-installation/main/caddy_443.json
```
### 下载并修改Caddy配置文件（非443端口）
```
wget -O /usr/local/etc/caddy.json https://raw.githubusercontent.com/TinrLin/NaiveProxy-installation/main/caddy_1234.json 
```
### 测试Caddy配置文件
```
/usr/bin/caddy run --environ --config /usr/local/etc/caddy.json
```
### 启动并查看Caddy的运行状态
```
systemctl daemon-reload && systemctl enable --now caddy && systemctl status caddy
```
### 重新加载Caddy配置文件
```
systemctl reload caddy
```
