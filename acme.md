- **install acme**
```
apt -y install curl && curl https://get.acme.sh | sh 
```
 - **set acme alias**
```
alias acme.sh=~/.acme.sh/acme.sh
```
- **auto update acme**
```
acme.sh --upgrade --auto-upgrade
```
- **Set acme's default CA**
```
acme.sh --set-default-ca --server letsencrypt
```
- **generate certificate(Replace www.example.com with your domain name）**
```
acme.sh --issue -d www.example.com --standalone -k ec-256 --webroot /home/wwwroot/html
```
- **install certificate(Replace www.example.com with your domain name）**
```
acme.sh --install-cert -d www.example.com --ecc --key-file /etc/ssl/private/private.key --fullchain-file /etc/ssl/private/cert.crt
```
