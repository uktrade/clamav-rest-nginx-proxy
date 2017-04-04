#!/bin/bash

set -euo pipefail

# Validate environment variables
: "${PROXY_TARGET:?Set PROXY_TARGET using --env}"
: "${TARGET_PORT:?Set TARGET_PORT using --env}"


echo ">> generating self signed cert"
openssl req -x509 -newkey rsa:4086 \
-subj "/C=XX/ST=XXXX/L=XXXX/O=XXXX/CN=localhost" \
-keyout "/key.pem" \
-out "/cert.pem" \
-days 3650 -nodes -sha256

# Template an nginx.conf
cat <<EOF >/etc/nginx/nginx.conf
user nginx;
worker_processes 2;

events {
  worker_connections 1024;
}

EOF

cat <<EOF >>/etc/nginx/nginx.conf

upstream clamav_rest {
    server ${PROXY_TARGET}:${TARGET_PORT};
}

http {
  access_log /var/log/nginx/access.log;
  error_log /var/log/nginx/error.log;

  server {
    listen 443 ssl;
    server_name localhost;
    #root /usr/share/nginx/html;
    ssl_certificate /cert.pem;
    ssl_certificate_key /key.pem;
    
    include /etc/nginx/mime.types;
    real_ip_header X-Forwarded-For;
    real_ip_recursive on;
    set_real_ip_from 172.16.0.0/20;
    set_real_ip_from 192.168.0.0/16;
    set_real_ip_from 10.0.0.0/8;
  
    location / {
        proxy_pass http://clamav_rest;
    } 
  }
}
EOF


# Launch nginx in the foreground
/usr/sbin/nginx -g "daemon off;"
