#!/bin/bash

# Скрипт резервного копирования текущей Docker инфраструктуры
# Выполнять ПЕРЕД миграцией на K8s
# ИСПРАВЛЕННАЯ ВЕРСИЯ с правильными именами БД и пользователями

set -e

BACKUP_DIR="./backups/pre-k8s-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "=== Создание резервных копий ==="
echo "Директория: $BACKUP_DIR"

# 1. Бэкап PostgreSQL баз данных
echo ""
echo "[1/5] Бэкап PostgreSQL - Synapse..."
docker exec matrix-postgres pg_dump -U matrix synapse > "$BACKUP_DIR/synapse.sql"

echo "[2/5] Бэкап PostgreSQL - MAS..."
docker exec matrix-postgres pg_dump -U matrix mas > "$BACKUP_DIR/mas.sql"

# 2. Бэкап конфигурационных файлов
echo "[3/5] Бэкап конфигураций..."
cp -r ./mas-config "$BACKUP_DIR/" 2>/dev/null || echo "mas-config не найден"
cp -r ./livekit-config "$BACKUP_DIR/" 2>/dev/null || echo "livekit-config не найден"
cp .env "$BACKUP_DIR/.env" 2>/dev/null || echo ".env не найден"
cp docker-compose.yml "$BACKUP_DIR/docker-compose.yml"

# 3. Экспорт данных Synapse (media, signing keys)
echo "[4/5] Бэкап Synapse data..."
docker cp matrix-synapse:/data "$BACKUP_DIR/synapse-data" 2>/dev/null || echo "Synapse data volume недоступен"

# 4. Список запущенных контейнеров
echo "[5/5] Сохранение состояния системы..."
docker ps -a > "$BACKUP_DIR/docker-ps.txt"
docker images > "$BACKUP_DIR/docker-images.txt"
docker network ls > "$BACKUP_DIR/docker-networks.txt"

# 5. Создание архива
echo ""
echo "Создание архива..."
tar -czf "$BACKUP_DIR.tar.gz" -C "./backups" "$(basename $BACKUP_DIR)"

echo ""
echo "=== Резервное копирование завершено! ==="
echo ""
echo "Архив: $BACKUP_DIR.tar.gz"
echo "Размер: $(du -h $BACKUP_DIR.tar.gz | cut -f1)"
echo ""
echo "Для восстановления:"
echo "  tar -xzf $BACKUP_DIR.tar.gz"
echo "  cat $BACKUP_DIR/synapse.sql | docker exec -i matrix-postgres psql -U matrix synapse"
