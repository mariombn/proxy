# Proxy Reverso Nginx com Docker

Proxy reverso Nginx com suporte a HTTPS via Let's Encrypt para aplicações na VPS.

## Estrutura

```
proxy/
├── docker-compose.yml
├── nginx/
│   ├── nginx.conf
│   └── conf.d/
│       └── devtools.conf
├── certbot/
│   ├── conf/
│   └── www/
├── init-ssl.sh
└── README.md
```

## Configuração Inicial

### 1. Certificados SSL

**IMPORTANTE:** Antes de rodar, edite `init-ssl.sh` e substitua `seu-email@exemplo.com` pelo seu email.

```bash
chmod +x init-ssl.sh
./init-ssl.sh
```

### 2. Subir o proxy (se já tiver certificados)

```bash
docker compose up -d
```

## Adicionar Nova Aplicação

Para adicionar um novo subdomínio (ex: `app2.mariombn.com` na porta 3001):

1. Criar arquivo `nginx/conf.d/app2.conf`:

```nginx
server {
    listen 80;
    server_name app2.mariombn.com;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name app2.mariombn.com;

    ssl_certificate /etc/letsencrypt/live/app2.mariombn.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/app2.mariombn.com/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    location / {
        proxy_pass http://host.docker.internal:3001;
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
```

2. Obter certificado:

```bash
docker compose run --rm certbot certonly --webroot \
    --webroot-path=/var/www/certbot \
    --email seu-email@exemplo.com \
    --agree-tos \
    --no-eff-email \
    -d app2.mariombn.com
```

3. Recarregar nginx:

```bash
docker compose exec nginx nginx -s reload
```

## Comandos Úteis

```bash
# Ver logs
docker compose logs -f nginx

# Recarregar configuração
docker compose exec nginx nginx -s reload

# Parar
docker compose down

# Renovar certificados manualmente
docker compose run --rm certbot renew
```

## Notas

- Certificados renovam automaticamente a cada 12h
- Porta 80 redireciona para 443 (HTTPS)
- Aplicações devem rodar no host (não em containers) ou usar `host.docker.internal`
- Se apps estiverem em containers na mesma rede Docker, use o nome do container ao invés de `host.docker.internal:porta`
