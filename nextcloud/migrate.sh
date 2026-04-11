#!/bin/bash
set -e

# =============================================================================
# Nextcloud Migration: K3s → Docker Compose
# Этот скрипт выполняет безопасную миграцию с возможностью отката на каждом шаге.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="/tmp/nextcloud-migration-backup"
KUBECONFIG_TMP="/tmp/k3s.yaml"

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

confirm() {
    read -p "$1 [y/N]: " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# =============================================================================
# ФАЗА 1: Сухой запуск (без данных K3s)
# =============================================================================
phase1() {
    info "========== ФАЗА 1: Сухой запуск =========="
    info "Собираем и запускаем Docker Compose Nextcloud с чистой БД..."

    cd "$SCRIPT_DIR"
    docker compose up -d --build

    info "Ждём 40 секунд, пока Nextcloud проинициализируется..."
    sleep 40

    info "Проверяем статус контейнеров..."
    docker compose ps

    info "Проверяем RAR расширение..."
    if docker exec nextcloud php -m | grep -q rar; then
        info "✅ RAR расширение установлено!"
    else
        error "❌ RAR расширение НЕ найдено!"
        return 1
    fi

    info "Проверяем статус Nextcloud..."
    docker exec -u www-data nextcloud php occ status

    echo ""
    info "========== ФАЗА 1 ЗАВЕРШЕНА =========="
    info "Docker Compose Nextcloud работает с чистой БД."
    info "Можете проверить: http://<IP-сервера>:8080 (если проброшен порт)"
    echo ""
    warn "Следующий шаг: запустите './migrate.sh phase2' для миграции данных"
    warn "Или './migrate.sh rollback' для отката"
}

# =============================================================================
# ФАЗА 2: Миграция данных из K3s
# =============================================================================
phase2() {
    info "========== ФАЗА 2: Миграция данных =========="

    # Подготовка kubeconfig
    if [ -f /etc/rancher/k3s/k3s.yaml ]; then
        sudo cp /etc/rancher/k3s/k3s.yaml "$KUBECONFIG_TMP"
        sudo chown $(id -u):$(id -g) "$KUBECONFIG_TMP"
        chmod 644 "$KUBECONFIG_TMP"
        export KUBECONFIG="$KUBECONFIG_TMP"
    else
        error "K3s kubeconfig не найден! Убедитесь, что K3s запущен."
        return 1
    fi

    # Создаём папку для бекапов
    mkdir -p "$BACKUP_DIR"

    # 1. Maintenance mode в K3s
    info "1/8 Включаем maintenance mode в K3s Nextcloud..."
    kubectl exec -n nextcloud deployment/nextcloud -- \
        su -s /bin/sh www-data -c "php occ maintenance:mode --on"

    # 2. Дамп базы данных
    info "2/8 Делаем дамп базы данных из K3s MariaDB..."
    # Пробуем разные варианты имени пода MariaDB
    MARIADB_POD=$(kubectl get pods -n nextcloud -l app.kubernetes.io/name=mariadb -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    if [ -z "$MARIADB_POD" ]; then
        MARIADB_POD=$(kubectl get pods -n nextcloud | grep mariadb | head -1 | awk '{print $1}')
    fi

    if [ -z "$MARIADB_POD" ]; then
        error "Не найден под MariaDB в namespace nextcloud!"
        error "Проверьте: kubectl get pods -n nextcloud"
        return 1
    fi

    info "   Найден MariaDB под: $MARIADB_POD"
    kubectl exec -n nextcloud "$MARIADB_POD" -- \
        mysqldump -u nextcloud -pnextcloud nextcloud > "$BACKUP_DIR/nextcloud-db.sql"

    DB_SIZE=$(du -h "$BACKUP_DIR/nextcloud-db.sql" | cut -f1)
    info "   Дамп сохранён: $BACKUP_DIR/nextcloud-db.sql ($DB_SIZE)"

    # 3. Сохраняем config.php
    info "3/8 Сохраняем config.php..."
    NC_POD=$(kubectl get pod -n nextcloud -l app.kubernetes.io/name=nextcloud -o jsonpath='{.items[0].metadata.name}')
    kubectl cp "nextcloud/$NC_POD:/var/www/html/config/config.php" "$BACKUP_DIR/config.php.backup" 2>/dev/null || \
        kubectl exec -n nextcloud "$NC_POD" -- cat /var/www/html/config/config.php > "$BACKUP_DIR/config.php.backup"
    info "   Config сохранён: $BACKUP_DIR/config.php.backup"

    # 4. Останавливаем Docker Compose и пересоздаём с чистыми volumes
    info "4/8 Пересоздаём Docker Compose Nextcloud с чистой БД..."
    cd "$SCRIPT_DIR"
    docker compose down -v

    # 5. Запускаем только БД
    info "5/8 Запускаем MariaDB..."
    docker compose up -d nextcloud-db
    info "   Ждём 15 секунд..."
    sleep 15

    # 6. Восстанавливаем дамп
    info "6/8 Восстанавливаем дамп базы данных..."
    docker exec -i nextcloud-db mysql -u nextcloud -pnextcloud nextcloud < "$BACKUP_DIR/nextcloud-db.sql"
    info "   ✅ Дамп восстановлен!"

    # 7. Запускаем всё
    info "7/8 Запускаем все контейнеры..."
    docker compose up -d
    info "   Ждём 40 секунд (чтобы Nextcloud скопировал файлы в volume)..."
    sleep 40

    info "   Восстанавливаем старый config.php..."
    docker cp "$BACKUP_DIR/config.php.backup" nextcloud:/var/www/html/config/config.php
    docker exec nextcloud chown www-data:www-data /var/www/html/config/config.php
    docker exec -u www-data nextcloud php occ upgrade || true

    # 8. Обновляем конфиг
    info "8/8 Обновляем конфигурацию Nextcloud (Docker)..."
    docker exec -u www-data nextcloud php occ config:system:set dbhost --value="nextcloud-db"
    docker exec -u www-data nextcloud php occ config:system:set redis host --value="nextcloud-redis"
    docker exec -u www-data nextcloud php occ config:system:set redis password --value="redispassword"
    docker exec -u www-data nextcloud php occ config:system:set redis port --value="6379" --type=integer

    # Снимаем maintenance mode
    docker exec -u www-data nextcloud php occ maintenance:mode --off

    # Пересканировать файлы
    info "Пересканируем файлы..."
    docker exec -u www-data nextcloud php occ files:scan --all

    echo ""
    info "========== ФАЗА 2 ЗАВЕРШЕНА =========="
    info "Проверяем результат..."
    echo ""

    docker exec -u www-data nextcloud php occ status
    echo ""
    info "Список пользователей:"
    docker exec -u www-data nextcloud php occ user:list
    echo ""

    info "✅ Миграция данных завершена!"
    warn "Следующий шаг: обновите NPM (cloud.gigglin.tech → Forward: nextcloud:80)"
    warn "После проверки через браузер запустите './migrate.sh verify'"
}

# =============================================================================
# ПРОВЕРКА
# =============================================================================
verify() {
    info "========== ПРОВЕРКА =========="

    info "Статус контейнеров:"
    cd "$SCRIPT_DIR"
    docker compose ps
    echo ""

    info "RAR расширение:"
    docker exec nextcloud php -m | grep rar && info "✅ RAR OK" || error "❌ RAR не найден"
    echo ""

    info "Nextcloud статус:"
    docker exec -u www-data nextcloud php occ status
    echo ""

    info "Пользователи:"
    docker exec -u www-data nextcloud php occ user:list
    echo ""

    info "Cron:"
    docker exec -u www-data nextcloud php occ background:cron
    echo ""

    info "========== ПРОВЕРКА ЗАВЕРШЕНА =========="
}

# =============================================================================
# ОТКАТ
# =============================================================================
rollback() {
    warn "========== ОТКАТ =========="

    info "Останавливаем Docker Compose Nextcloud..."
    cd "$SCRIPT_DIR"
    docker compose down

    # Проверяем, есть ли K3s
    if [ -f /etc/rancher/k3s/k3s.yaml ]; then
        sudo cp /etc/rancher/k3s/k3s.yaml "$KUBECONFIG_TMP"
        sudo chown $(id -u):$(id -g) "$KUBECONFIG_TMP"
        chmod 644 "$KUBECONFIG_TMP"
        export KUBECONFIG="$KUBECONFIG_TMP"

        info "Снимаем maintenance mode в K3s Nextcloud..."
        kubectl exec -n nextcloud deployment/nextcloud -- \
            su -s /bin/sh www-data -c "php occ maintenance:mode --off" 2>/dev/null || \
            warn "Не удалось снять maintenance mode (возможно, он не был включён)"
    fi

    info "✅ Откат завершён. K3s Nextcloud должен работать как раньше."
    warn "Не забудьте вернуть NPM на старый NodePort, если меняли!"
}

# =============================================================================
# MAIN
# =============================================================================
case "${1:-}" in
    phase1)  phase1  ;;
    phase2)  phase2  ;;
    verify)  verify  ;;
    rollback) rollback ;;
    *)
        echo "Использование: $0 {phase1|phase2|verify|rollback}"
        echo ""
        echo "  phase1   - Сухой запуск (чистая установка, проверка RAR)"
        echo "  phase2   - Миграция данных из K3s (дамп БД + восстановление)"
        echo "  verify   - Проверка после миграции"
        echo "  rollback - Откат на K3s"
        ;;
esac
