#!/usr/bin/env sh
set -e

PORT=${PORT:-8080}

cat > /etc/nginx/conf.d/default.conf <<EOF
server {
    listen ${PORT} default_server;
    listen [::]:${PORT} default_server;
    server_name _;
    root /usr/share/nginx/html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location = /404.html {
        internal;
    }
}
EOF

exec nginx -g 'daemon off;' 
