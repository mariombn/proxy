#!/bin/bash

# Script para inicializar o proxy reverso com certificados SSL

echo "Iniciando configuração do proxy reverso..."

# Primeiro, iniciar o nginx apenas para HTTP (para validação do certbot)
echo "Criando configuração temporária para obter certificados..."

cat > nginx/conf.d/devtools.conf << 'EOF'
server {
    listen 80;
    server_name devtools.mariombn.com;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 200 'OK';
        add_header Content-Type text/plain;
    }
}
EOF

# Subir os containers
echo "Iniciando containers..."
docker compose up -d

# Aguardar nginx iniciar
echo "Aguardando nginx iniciar..."
sleep 10

# Obter certificados SSL
echo "Obtendo certificados SSL para devtools.mariombn.com..."
docker compose run --rm certbot certonly --webroot \
    --webroot-path=/var/www/certbot \
    --email mariombn@gmail.com \
    --agree-tos \
    --no-eff-email \
    -d devtools.mariombn.com

# Restaurar configuração completa com HTTPS
echo "Restaurando configuração com HTTPS..."
cat > nginx/conf.d/devtools.conf << 'EOF'
server {
    listen 80;
    server_name devtools.mariombn.com;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name devtools.mariombn.com;

    ssl_certificate /etc/letsencrypt/live/devtools.mariombn.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/devtools.mariombn.com/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    location / {
        proxy_pass http://host.docker.internal:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

# Recarregar nginx
echo "Recarregando nginx..."
docker compose exec nginx nginx -s reload

echo "Configuração concluída!"
echo "Acesse: https://devtools.mariombn.com"
