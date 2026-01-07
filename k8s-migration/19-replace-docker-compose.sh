#!/bin/bash
set -e

echo "=========================================="
echo "  Замена docker-compose.yml на minimal версию"
echo "=========================================="
echo ""

# Проверить что уже запущен cleanup скрипт
echo "⚠️  Сначала запусти: ./18-cleanup-old-matrix-containers.sh"
echo ""
read -p "Вы уже удалили старые Matrix контейнеры? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Сначала запустите 18-cleanup-old-matrix-containers.sh"
    exit 1
fi

cd ~/vps-server

echo ""
echo "=== Backup текущего docker-compose.yml ==="
if [ -f "docker-compose.yml" ]; then
    BACKUP_NAME="docker-compose.yml.backup-$(date +%Y%m%d-%H%M%S)"
    mv docker-compose.yml "$BACKUP_NAME"
    echo "✅ Backup создан: $BACKUP_NAME"
else
    echo "ℹ️  docker-compose.yml уже не существует"
fi

echo ""
echo "=== Копирование minimal docker-compose ==="
if [ -f "docker-compose-minimal.yml" ]; then
    cp docker-compose-minimal.yml docker-compose.yml
    echo "✅ docker-compose-minimal.yml → docker-compose.yml"
else
    echo "❌ docker-compose-minimal.yml не найден!"
    echo "Убедитесь что вы сделали 'git pull'"
    exit 1
fi

echo ""
echo "=== Остановка всех текущих Docker Compose сервисов ==="
docker-compose down 2>/dev/null || echo "docker-compose уже остановлен"

echo ""
echo "=== Запуск minimal сервисов ==="
docker-compose up -d

echo ""
echo "=== Проверка запущенных контейнеров ==="
echo ""
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "=========================================="
echo "✅ Замена завершена!"
echo "=========================================="
echo ""
echo "Сейчас автозапуск настроен для:"
echo "  ✅ nginx-proxy-manager (NPM)"
echo "  ✅ 3x-ui (VPN панель)"
echo "  ✅ landing (nginx статика)"
echo "  ⏸️  telegram-bot (закомментирован в docker-compose.yml)"
echo ""
echo "Matrix сервисы в K3s автоматически запускаются с системой"
echo ""
echo "Для добавления telegram-bot:"
echo "  1. Раскомментируйте секцию telegram-bot в docker-compose.yml"
echo "  2. docker-compose up -d telegram-bot"
echo ""
