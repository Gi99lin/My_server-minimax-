#!/bin/bash
set -e

echo "=========================================="
echo "  Удаление старых Matrix Docker контейнеров"
echo "=========================================="
echo ""
echo "Будут УДАЛЕНЫ:"
echo "  - matrix-synapse (Synapse homeserver)"
echo "  - mas (Matrix Authentication Service)"
echo "  - matrix-postgres (PostgreSQL для Matrix)"
echo "  - livekit (LiveKit SFU сервер)"
echo "  - livekit-jwt-service (JWT сервис)"
echo "  - redis (для LiveKit)"
echo ""
echo "Будут СОХРАНЕНЫ:"
echo "  ✅ nginx-proxy-manager (NPM для proxy)"
echo "  ✅ 3x-ui (VPN панель)"
echo "  ✅ landing (лендинг)"
echo "  ✅ telegram-bot (ваш бот)"
echo ""
read -p "Продолжить? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Отменено."
    exit 0
fi

echo ""
echo "=== Остановка и удаление Matrix контейнеров ==="

# Остановить и удалить Matrix-related контейнеры
MATRIX_CONTAINERS=(
    "matrix-synapse"
    "mas"
    "matrix-postgres"
    "livekit"
    "livekit-jwt-service"
    "redis"
)

for container in "${MATRIX_CONTAINERS[@]}"; do
    echo "Проверка $container..."
    if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        echo "  Остановка $container..."
        docker stop "$container" 2>/dev/null || true
        echo "  Удаление $container..."
        docker rm "$container" 2>/dev/null || true
        echo "  ✅ $container удален"
    else
        echo "  ⏭️  $container не найден"
    fi
done

echo ""
echo "=== Удаление связанных Docker volumes ==="

# Volumes которые использовались Matrix стеком
MATRIX_VOLUMES=(
    "vps-server_synapse_data"
    "vps-server_postgres_data"
    "vps-server_mas_data"
    "vps-server_livekit_data"
    "vps-server_redis_data"
)

for volume in "${MATRIX_VOLUMES[@]}"; do
    echo "Проверка $volume..."
    if docker volume ls --format '{{.Name}}' | grep -q "^${volume}$"; then
        echo "  Удаление $volume..."
        docker volume rm "$volume" 2>/dev/null || true
        echo "  ✅ $volume удален"
    else
        echo "  ⏭️  $volume не найден"
    fi
done

echo ""
echo "=== Отключение автозапуска (docker-compose.yml) ==="

# Проверить docker-compose.yml
if [ -f "docker-compose.yml" ]; then
    echo "⚠️  ВАЖНО: docker-compose.yml все еще существует"
    echo ""
    echo "Рекомендации:"
    echo "1. Переместить docker-compose.yml в backup:"
    echo "   mv docker-compose.yml docker-compose.yml.backup"
    echo ""
    echo "2. Или создать новый docker-compose.yml только с NPM + 3x-ui + landing + bot"
    echo ""
    echo "Без этого Matrix контейнеры могут пересоздаться при 'docker-compose up'"
    echo ""
    read -p "Переместить docker-compose.yml в backup? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mv docker-compose.yml docker-compose.yml.backup-$(date +%Y%m%d-%H%M%S)
        echo "✅ docker-compose.yml перемещен в backup"
    fi
fi

echo ""
echo "=== Проверка оставшихся контейнеров ==="
echo ""
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"

echo ""
echo "=========================================="
echo "✅ Очистка завершена!"
echo "=========================================="
echo ""
echo "Сейчас запущены только:"
echo "  - Nginx Proxy Manager (порты 80, 81, 443)"
echo "  - 3x-ui (VPN панель)"
echo "  - landing (nginx лендинг)"
echo "  - telegram-bot (если не Restarting)"
echo ""
echo "Matrix сервисы теперь работают в K3s (namespace: ess)"
echo ""
echo "Проверить K3s pods:"
echo "  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
echo "  kubectl get pods -n ess"
echo ""
