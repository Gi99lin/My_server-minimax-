# Deploy Instructions

## DNS Setup (ВАЖНО!)

| Type | Host | Value |
|------|------|-------|
| A | @ | 37.60.251.4 |
| A | www | 37.60.251.4 |
| CNAME | vpn | gigglin.tech |
| CNAME | matrix | gigglin.tech |
| CNAME | auth | gigglin.tech |

## On VPS (37.60.251.4)

### 1. Установка Docker

```bash
ssh root@37.60.251.4

# Установить Docker
curl -fsSL https://get.docker.com | sh
```

### 2. Клонирование и настройка

```bash
# Клонировать репозиторий
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git /root/vps-server
cd /root/vps-server

# Создать .env
cp .env.example .env
nano .env
```

Заполните `.env`:
```env
MATRIX_DOMAIN=gigglin.tech
POSTGRES_PASSWORD=ваш_надежный_пароль

# Email (Yandex)
SMTP_HOST=smtp.yandex.ru
SMTP_PORT=587
SMTP_USERNAME=your-email@yandex.ru
SMTP_PASSWORD=пароль_приложения_yandex
SMTP_FROM_EMAIL=your-email@yandex.ru
SMTP_FROM_NAME=gigglin.tech
```

### 3. Настройка MAS конфига

```bash
nano mas-config/config.yaml
```

Измените:
- `database.uri` - пароль PostgreSQL должен совпадать с POSTGRES_PASSWORD
- `email.*` - данные SMTP из .env
- `secrets.*` - сгенерировать новые для продакшена

### 4. Запуск

```bash
docker compose up -d
docker compose ps
```

### 5. Проверка логов

```bash
docker logs mas --tail 20
docker logs matrix-synapse --tail 20
```

## Nginx Proxy Manager Setup

### Доступ

URL: http://37.60.251.4:81  
Login: admin@example.com  
Password: changeme

### Создание Proxy Hosts

**1. gigglin.tech (Landing + .well-known)**

- Domain Names: `gigglin.tech`, `www.gigglin.tech`
- Forward Hostname/IP: `landing`
- Forward Port: `80`
- SSL: Let's Encrypt ✓

**Advanced → Custom Nginx Configuration:**
```nginx
location /.well-known/matrix/client {
    add_header Content-Type application/json;
    add_header Access-Control-Allow-Origin *;
    return 200 '{"m.homeserver":{"base_url":"https://matrix.gigglin.tech"},"org.matrix.msc2965.authentication":{"issuer":"https://auth.gigglin.tech/","account":"https://auth.gigglin.tech/account"}}';
}
```

**2. auth.gigglin.tech (MAS)**

- Domain Names: `auth.gigglin.tech`
- Forward Hostname/IP: `mas`
- Forward Port: `8080`
- SSL: Let's Encrypt ✓

**3. matrix.gigglin.tech (Synapse)**

- Domain Names: `matrix.gigglin.tech`
- Forward Hostname/IP: `matrix-synapse`
- Forward Port: `8008`
- SSL: Let's Encrypt ✓

**4. vpn.gigglin.tech (3x-ui)**

- Domain Names: `vpn.gigglin.tech`
- Forward Hostname/IP: `3x-ui`
- Forward Port: `2053`
- SSL: Let's Encrypt ✓

## Проверка работоспособности

```bash
# .well-known для Matrix
curl https://gigglin.tech/.well-known/matrix/client

# MAS OpenID Configuration
curl https://auth.gigglin.tech/.well-known/openid-configuration

# Synapse API
curl https://matrix.gigglin.tech/_matrix/client/versions
```

## First Login

| Service | URL | Credentials |
|---------|-----|-------------|
| NPM Admin | http://37.60.251.4:81 | admin@example.com / changeme |
| 3x-ui | https://vpn.gigglin.tech | admin / admin |
| Element X | gigglin.tech | Регистрация через MAS |

## Matrix (Element X)

1. Скачайте Element X (iOS/Android)
2. Выберите "Other" → введите `gigglin.tech`
3. Нажмите "Sign Up"
4. Введите email и пароль
5. Подтвердите email (код придёт на почту)
6. Готово!

## Yandex SMTP Setup

1. Включите 2FA: https://id.yandex.ru/security
2. Создайте пароль приложения: https://id.yandex.ru/security/app-passwords
3. Выберите тип "Почта"
4. Скопируйте пароль в SMTP_PASSWORD

## Сброс баз данных (при проблемах)

```bash
docker compose stop mas matrix-synapse

docker exec matrix-postgres psql -U matrix -d postgres -c "DROP DATABASE IF EXISTS mas;"
docker exec matrix-postgres psql -U matrix -d postgres -c "DROP DATABASE IF EXISTS synapse;"
docker exec matrix-postgres psql -U matrix -d postgres -c "CREATE DATABASE mas OWNER matrix;"
docker exec matrix-postgres psql -U matrix -d postgres -c "CREATE DATABASE synapse OWNER matrix;"

docker compose up -d mas matrix-synapse
```

## Обновление

```bash
cd /root/vps-server
git pull
docker compose pull
docker compose up -d
```
