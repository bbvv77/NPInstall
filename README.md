- **Install go**
 **Linux AMD64**
```
apt -y update && apt -y install wget socat curl && wget -c https://go.dev/dl/go1.20.5.linux-amd64.tar.gz -O - | tar -xz -C /usr/local && echo 'export PATH=$PATH:/usr/local/go/bin' > /etc/profile && source /etc/profile && go version 
```
- **Compile and install caddy**
```
go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest && ~/go/bin/xcaddy build --output caddy --with github.com/mholt/caddy-l4 --with github.com/mastercactapus/caddy2-proxyprotocol --with github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@naive && setcap cap_net_bind_service=+ep ./caddy && chmod +x caddy && mv caddy /usr/bin/
```

- **Download caddy.service**
```
wget -P /etc/systemd/system https://raw.githubusercontent.com/TinrLin/NaiveProxy-installation/main/caddy.service
```
- **Download the caddy configuration file (port 443)**
```
wget -O /usr/local/etc/config.json https://raw.githubusercontent.com/TinrLin/NaiveProxy-installation/main/config_443.json
```
- **Download the caddy configuration file (not port 443), you need to prepare the certificate yourself**
```
wget -O /usr/local/etc/config.json https://raw.githubusercontent.com/TinrLin/NaiveProxy-installation/main/config.json 
```
- **Test if it works**
```
/usr/bin/caddy run --environ --config /usr/local/etc/config.json
```
- **Create unique Linux group and user for caddy**
```
 groupadd --system caddy && useradd --system --gid caddy --create-home --home-dir /var/lib/caddy --shell /usr/sbin/nologin --comment "Caddy web server" caddy
```
- **Check the current status**
```
systemctl daemon-reload && systemctl enable --now caddy && systemctl status caddy
```
- **Reload caddy with changed config file**
```
systemctl reload caddy
```
