#!/bin/bash

# Скрипт остановки Docker Matrix сервисов
# ВНИМАНИЕ: Выполнять только после успешного развёртывания ESS в K8s!

set -e

echo "=== Остановка Docker Matrix сервисов ==="
echo ""
echo "ВНИМАНИЕ: Этот скрипт остановит текущие Matrix сервисы в Docker!"
echo "Убедитесь, что ESS в K8s работает корректно."
echo ""
read -p "Продолжить? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Отменено."
    exit 0
fi

# Сервисы, которые ОСТАНОВИМ (Matrix stack)
STOP_SERVICES=(
    "matrix-synapse"
    "mas"
    "livekit"
    "livekit-jwt-service"
    "redis"
)

# Сервисы, которые ОСТАВИМ (инфраструктура)
KEEP_SERVICES=(
    "matrix-postgres"      # Общая БД, может использоваться K8s
    "nginx-proxy-manager"  # Reverse proxy
    "3x-ui"                # VPN
    "telegram-bot"         # Telegram bot
    "landing"              # Landing page
)

echo ""
echo "Будут остановлены:"
for service in "${STOP_SERVICES[@]}"; do
    echo "  - $service"
done

echo ""
echo "Останутся работать:"
for service in "${KEEP_SERVICES[@]}"; do
    echo "  - $service"
done

echo ""
read -p "Подтвердите (yes): " FINAL_CONFIRM

if [ "$FINAL_CONFIRM" != "yes" ]; then
    echo "Отменено."
    exit 0
fi

# Останавливаем сервисы
echo ""
echo "Останавливаем Matrix сервисы..."
for service in "${STOP_SERVICES[@]}"; do
    if docker ps -q -f name=$service > /dev/null 2>&1; then
        echo "Останавливаем $service..."
        docker stop $service
    else
        echo "$service не запущен"
    fi
done

echo ""
echo "=== Docker Matrix сервисы остановлены ==="
echo ""
echo "Проверка оставшихся контейнеров:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "Для полного удаления контейнеров (необратимо!):"
echo "  docker rm matrix-synapse matrix-mas livekit livekit-jwt-service redis"
echo ""
echo "Для удаления volumes (ПОТЕРЯ ДАННЫХ!):"
echo "  docker volume rm synapse-data mas-data redis-data"
