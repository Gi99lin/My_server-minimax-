# Инструкция по Очистке Старых Matrix Docker Контейнеров

## 📋 Что будет удалено

**Docker контейнеры:**
- `matrix-synapse` - Synapse homeserver
- `mas` - Matrix Authentication Service
- `matrix-postgres` - PostgreSQL для Matrix
- `livekit` - LiveKit SFU сервер
- `livekit-jwt-service` - JWT сервис для LiveKit
- `redis` - Redis для LiveKit

**Docker volumes:**
- `vps-server_synapse_data`
- `vps-server_postgres_data`
- `vps-server_mas_data`
- `vps-server_livekit_data`
- `vps-server_redis_data`

## ✅ Что останется

**Docker контейнеры:**
- `nginx-proxy-manager` - NPM для reverse proxy и SSL
- `3x-ui` - VPN панель
- `landing` - Статический лендинг
- `telegram-bot` - Telegram бот (если работает)

**Volumes:**
- `npm_data` - NPM конфигурация
- `npm_letsencrypt` - SSL сертификаты
- `3x-ui_data` - 3x-ui конфигурация

## 🚀 Порядок Выполнения

### Шаг 1: Удаление Matrix контейнеров

```bash
cd ~/vps-server
git pull
chmod +x k8s-migration/18-cleanup-old-matrix-containers.sh
./k8s-migration/18-cleanup-old-matrix-containers.sh
```

Скрипт:
1. Остановит и удалит все Matrix контейнеры
2. Удалит связанные Docker volumes
3. Предложит сделать backup `docker-compose.yml`

### Шаг 2: Замена docker-compose.yml

```bash
chmod +x k8s-migration/19-replace-docker-compose.sh
./k8s-migration/19-replace-docker-compose.sh
```

Скрипт:
1. Создаст backup текущего `docker-compose.yml`
2. Скопирует `docker-compose-minimal.yml` → `docker-compose.yml`
3. Перезапустит Docker Compose с новой конфигурацией

### Шаг 3: Проверка

```bash
# Docker контейнеры
docker ps -a

# K3s pods (Matrix в K8s)
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get pods -n ess
```

## 📦 Новая Структура docker-compose.yml

```yaml
version: '3.8'

services:
  nginx-proxy-manager:   # NPM для SSL и reverse proxy
  3x-ui:                 # VPN панель
  landing:               # Статический сайт
  # telegram-bot:        # Закомментирован (раскомментируйте при необходимости)
```

## 🔧 После Очистки

### Автозапуск при перезагрузке сервера

**Docker контейнеры (через docker-compose):**
- ✅ nginx-proxy-manager
- ✅ 3x-ui
- ✅ landing

**K3s pods (через systemd):**
- ✅ K3s автоматически запускается как systemd service
- ✅ Все ESS pods в namespace `ess` восстанавливаются автоматически

### Включение telegram-bot

Раскомментируйте в `docker-compose.yml`:

```yaml
  telegram-bot:
    build:
      context: .
      dockerfile: Dockerfile
    image: vps-server-telegram-bot
    container_name: telegram-bot
    restart: unless-stopped
    env_file:
      - .env
    networks:
      - proxy_network
```

Затем:
```bash
docker-compose up -d telegram-bot
```

## ⚠️ Важные Замечания

1. **Backup данных**: Volumes удаляются НАВСЕГДА. Убедитесь что все нужные данные в K3s.

2. **NPM конфигурация**: Proxy hosts в NPM остаются без изменений. Проверьте что все домены работают.

3. **K3s автозапуск**: K3s установлен как systemd service и запускается автоматически при boot.

4. **SSL сертификаты**: Let's Encrypt сертификаты в NPM не затрагиваются.

5. **3x-ui данные**: VPN конфигурация остается в volume `3x-ui_data`.

## 🧪 Тестирование После Очистки

### 1. Проверить Docker

```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```

Должны быть Running:
- nginx-proxy-manager
- 3x-ui
- landing

### 2. Проверить K3s

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get pods -n ess
```

Все pods должны быть Running:
- ess-synapse-main-0
- ess-postgres-0
- ess-matrix-authentication-service-*
- ess-element-web-*
- ess-element-admin-*
- ess-matrix-rtc-sfu-*
- ess-matrix-rtc-authorisation-service-*
- ess-haproxy-*

### 3. Проверить Matrix

```bash
# Synapse API
curl https://matrix.gigglin.tech/_matrix/client/versions

# Element Web
curl -I https://app.gigglin.tech

# .well-known
curl https://gigglin.tech/.well-known/matrix/client
```

### 4. Проверить NPM

Открыть в браузере:
- `http://37.60.251.4:81` - NPM admin panel
- Все proxy hosts должны показывать статус "Online"

## 🔄 Rollback (если что-то пошло не так)

### Восстановить docker-compose.yml

```bash
cd ~/vps-server
mv docker-compose.yml.backup-YYYYMMDD-HHMMSS docker-compose.yml
docker-compose up -d
```

### Восстановить контейнеры

```bash
docker-compose up -d
```

Volumes НЕ восстановятся (удалены навсегда). Нужен полный redeploy.

## 📊 Экономия Ресурсов

После очистки:

**Освобождено места:**
- Docker images: ~2-3 GB
- Docker volumes: ~500 MB - 2 GB (зависит от размера БД)

**Освобождено RAM:**
- ~1-2 GB (старые Matrix контейнеры больше не запущены)

**Упрощена архитектура:**
- Matrix полностью в K3s (единая платформа оркестрации)
- Docker только для NPM + утилиты (3x-ui, landing, bot)
- Легче мониторить и обслуживать

---

Создано: 2026-01-08  
Версия: 1.0
