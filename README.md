# VPS Server Setup - gigglin.tech

## Структура сервисов

| URL | Сервис | Порт контейнера |
|-----|--------|-----------------|
| gigglin.tech | Landing Page | 80 |
| vpn.gigglin.tech | 3x-ui (VPN панель) | 2053 |
| matrix.gigglin.tech | Matrix Synapse | 8008 |
| auth.gigglin.tech | Matrix Auth Service (MAS) | 8080 |
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
| CNAME | auth | gigglin.tech |

### 2. Запуск на VPS

```bash
git clone https://github.com/YOUR_REPO.git /root/vps-server
cd /root/vps-server

# Создать .env из примера
cp .env.example .env

# Редактировать .env
nano .env

# Запуск
docker compose up -d
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
SSL: Let's Encrypt
```

**Custom Nginx Config (Advanced):**
```nginx
location /.well-known/matrix/client {
    add_header Content-Type application/json;
    add_header Access-Control-Allow-Origin *;
    return 200 '{"m.homeserver":{"base_url":"https://matrix.gigglin.tech"},"org.matrix.msc2965.authentication":{"issuer":"https://auth.gigglin.tech/","account":"https://auth.gigglin.tech/account"}}';
}
```

**2. vpn.gigglin.tech (3x-ui)**
```
Domain Names: vpn.gigglin.tech
Scheme: http
Forward Hostname/IP: 3x-ui
Forward Port: 2053
SSL: Let's Encrypt
```

**3. matrix.gigglin.tech (Matrix Synapse)**
```
Domain Names: matrix.gigglin.tech
Scheme: http
Forward Hostname/IP: matrix-synapse
Forward Port: 8008
SSL: Let's Encrypt
```

**4. auth.gigglin.tech (MAS)**
```
Domain Names: auth.gigglin.tech
Scheme: http
Forward Hostname/IP: mas
Forward Port: 8080
SSL: Let's Encrypt
```

## Matrix + MAS (Element X поддержка)

Для работы Element X на iOS/Android требуется Matrix Authentication Service (MAS).

### Архитектура

```
Element X → gigglin.tech/.well-known/matrix/client
         → auth.gigglin.tech (MAS) - аутентификация OIDC
         → matrix.gigglin.tech (Synapse) - Matrix API
```

### Конфигурационные файлы

- `mas-config/config.yaml` - конфигурация MAS (OIDC, email, clients)
- `.env` - секреты (пароли БД, SMTP)

### Важные параметры MAS

```yaml
# Клиенты OAuth2
clients:
  - client_id: "0000000000000000000SYNAPSE"  # 26 символов ULID
    client_auth_method: client_secret_basic
    client_secret: "SynapseClientSecret123!"
  - client_id: "000000000000000000E1EMENTX"  # Element X
    client_auth_method: none
    grant_types:
      - authorization_code
      - refresh_token
      - "urn:ietf:params:oauth:grant-type:device_code"

# Email для верификации (Yandex SMTP)
email:
  from: '"gigglin.tech" <your-email@yandex.ru>'
  transport: smtp
  mode: starttls
  hostname: smtp.yandex.ru
  port: 587
  username: "your-email@yandex.ru"
  password: "app_password"

# Policy для динамической регистрации клиентов
policy:
  wasm_module: /usr/local/share/mas-cli/policy.wasm
  data:
    client_registration:
      allow_missing_contacts: true
```

### Сброс базы (если нужно начать заново)

```bash
docker compose stop mas matrix-synapse

docker exec matrix-postgres psql -U matrix -d postgres -c "DROP DATABASE IF EXISTS mas;"
docker exec matrix-postgres psql -U matrix -d postgres -c "DROP DATABASE IF EXISTS synapse;"
docker exec matrix-postgres psql -U matrix -d postgres -c "CREATE DATABASE mas OWNER matrix;"
docker exec matrix-postgres psql -U matrix -d postgres -c "CREATE DATABASE synapse OWNER matrix;"

docker compose up -d mas matrix-synapse
```

## Управление

```bash
# Статус
docker compose ps

# Логи
docker compose logs -f
docker logs mas --tail 50
docker logs matrix-synapse --tail 50

# Перезапуск
docker compose restart mas
docker compose restart matrix-synapse

# Обновление
docker compose pull
docker compose up -d
```

## Первый запуск Matrix

1. Установите Element X (iOS/Android)
2. Выберите "Other" → введите `gigglin.tech`
3. Нажмите "Sign Up"
4. Заполните форму регистрации
5. Подтвердите email (код придёт на почту)
6. Готово!

## Главная страница

Landing page показывает "В разработке" с информацией о сервисах:
- 💬 Matrix Chat
- 🔒 Private VPN
- 🤖 Telegram Bot

## Файлы проекта

```
├── docker-compose.yml       # Все сервисы
├── .env                     # Секреты (не коммитить!)
├── .env.example             # Пример .env
├── mas-config/
│   └── config.yaml          # Конфиг MAS
├── nginx-landing/           # Landing page
├── postgres-init/
│   └── init-mas.sql         # Инициализация БД
├── telegram-bot/            # Telegram бот
└── plans/
```

## Troubleshooting

### MAS не запускается

```bash
docker logs mas --tail 50
```

Частые проблемы:
- `missing field 'secrets'` - неправильный формат config.yaml
- `authentication failed` - неверные SMTP credentials
- `Sender address rejected` - email в `from` не совпадает с `username`

### Element X не подключается

1. Проверьте `.well-known/matrix/client`:
   ```bash
   curl https://gigglin.tech/.well-known/matrix/client
   ```

2. Проверьте MAS OpenID:
   ```bash
   curl https://auth.gigglin.tech/.well-known/openid-configuration
   ```

3. Проверьте Synapse:
   ```bash
   curl https://matrix.gigglin.tech/_matrix/client/versions
   ```
