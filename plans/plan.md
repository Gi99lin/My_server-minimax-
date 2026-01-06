# План развёртывания сервера с Docker

## Предварительные требования
- VPS с Debian/Ubuntu
- Статический IP
- Домен, направленный на IP сервера
- Минимум 2GB RAM, 20GB SSD

## Шаги

### 1. Подготовка сервера
```bash
# Обновление системы
sudo apt update && sudo apt upgrade -y

# Установка Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Установка Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### 2. Настройка DNS
- Купить домен (рекомендую: Namecheap, Reg.ru, Cloudflare)
- Создать A-запись: `your-domain.com -> YOUR_SERVER_IP`
- Добавить запись для Matrix: `matrix.your-domain.com -> YOUR_SERVER_IP`
- Дождаться распространения DNS (до 24 часов, обычно 5-15 минут)

### 3. Конфигурация проекта
1. Клонировать репозиторий на сервер
2. Скопировать `.env.example` в `.env`
3. Заполнить переменные окружения:
   - `MATRIX_DOMAIN` = ваш домен
   - `POSTGRES_PASSWORD` = сложный пароль
   - `TELEGRAM_BOT_TOKEN` = токен бота

### 4. Добавление SSL с Let's Encrypt
Рекомендую использовать [nginx-proxy-manager](https://nginxproxymanager.com/) для управления SSL:

```yaml
# Добавить в docker-compose.yml
nginx-proxy-manager:
  image: jc21/nginx-proxy-manager:latest
  restart: unless-stopped
  ports:
    - "80:80"     # HTTP
    - "443:443"   # HTTPS
    - "81:81"     # Admin UI
  volumes:
    - nginx-data:/data
    - nginx-letsencrypt:/etc/letsencrypt
  depends_on:
    - 3x-ui
    - matrix-synapse
```

### 5. Запуск
```bash
docker-compose up -d
```

### 6. Настройка сервисов

#### 3x-ui
- Открыть: `http://your-server:2053`
- Логин/пароль по умолчанию: `admin` / `admin`
- Сменить пароль!

#### Matrix Synapse
- Подождать 2-3 минуты для инициализации
- Зарегистрировать первого пользователя:
```bash
docker exec -it matrix-synapse register_new_matrix_user \
  http://localhost:8008 -c /data/config/homeserver.yaml
```
- Использовать клиент: [Element Web](https://app.element.io)

#### Telegram Bot
- Поместить код бота в `telegram-bot/bot.py`
- Запустить: `docker-compose up -d --build telegram-bot`

## Структура файлов
```
├── docker-compose.yml
├── .env.example
├── .env
├── README.md
├── telegram-bot/
│   ├── Dockerfile
│   ├── bot.py
│   └── requirements.txt
└── plans/
    └── plan.md
```

## Рекомендуемые порты
| Порт | Сервис | Описание |
|------|--------|----------|
| 80 | HTTP | Для редиректа на HTTPS |
| 443 | HTTPS | Основной HTTPS порт |
| 81 | Nginx PM | Admin UI (закрыть firewall!) |
| 2053 | 3x-ui | VPN панель |

## Firewall (ufw)
```bash
sudo ufw allow ssh
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable
```

## Бекапы
Создать скрипт `backup.sh`:
```bash
#!/bin/bash
docker-compose down
tar czf backup-$(date +%Y%m%d).tar.gz data/ docker-compose.yml .env
docker-compose up -d
```
