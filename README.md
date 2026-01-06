# VPS Server Setup - gigglin.tech

## Структура сервисов

| URL | Сервис | Порт контейнера |
|-----|--------|-----------------|
| gigglin.tech | Landing Page | 80 |
| vpn.gigglin.tech | 3x-ui (VPN панель) | 2053 |
| matrix.gigglin.tech | Matrix Chat | 8008/8448 |
| 37.60.251.4:81 | Nginx Proxy Manager | 81 |

## Быстрый старт

### 1. Настройка DNS

Добавьте записи в DNS панели:

| Тип | Хост | Значение |
|-----|------|----------|
| A | @ | 37.60.251.4 |
| A | www | 37.60.251.4 |
| CNAME | vpn | gigglin.tech |
| CNAME | matrix | gigglin.tech |

### 2. Запуск на VPS

```bash
git clone https://github.com/YOUR_REPO.git /opt/vps-server
cd /opt/vps-server

# Редактировать .env
nano .env

# Запуск
docker-compose up -d
```

### 3. Настройка Nginx Proxy Manager

Откройте http://37.60.251.4:81

**Логин:** admin@example.com
**Пароль:** changeme

#### Создание Proxy Hosts

**1. gigglin.tech (Landing)**
```
Domain Names: gigglin.tech, www.gigglin.tech
Scheme: http
Forward Hostname/IP: landing
Forward Port: 80
```

**2. vpn.gigglin.tech (3x-ui)**
```
Domain Names: vpn.gigglin.tech
Scheme: http
Forward Hostname/IP: 3x-ui
Forward Port: 2053
```

**3. matrix.gigglin.tech (Matrix API)**
```
Domain Names: matrix.gigglin.tech
Scheme: http
Forward Hostname/IP: matrix-synapse
Forward Port: 8008
```

#### SSL сертификаты

Для каждого домена:
1. Зайдите в SSL Certificates
2. Добавьте новый сертификат с "Let's Encrypt"
3. Включите "Force SSL"

## Управление

```bash
# Статус
docker-compose ps

# Логи
docker-compose logs -f

# Перезапуск
docker-compose restart 3x-ui

# Обновление
docker-compose pull
docker-compose up -d
```

## Первый запуск Matrix

```bash
# Подождите 2-3 минуты инициализации
docker exec -it matrix-synapse register_new_matrix_user http://localhost:8008 -c /data/config/homeserver.yaml
```

## Главная страница

Landing page показывает "В разработке" с информацией о сервисах:
- 💬 Matrix Chat
- 🔒 Private VPN
- 🤖 Telegram Bot

## Файлы проекта

```
├── docker-compose.yml
├── .env
├── README.md
├── DEPLOY.md
├── nginx-landing/     # Landing page
├── telegram-bot/      # Telegram бот
└── plans/
