#!/bin/bash

# Скрипт развёртывания Element Server Suite в K3s
# Выполнять после установки K3s и создания бэкапов

set -e

NAMESPACE="matrix"

echo "=== Развёртывание Element Server Suite ==="

# 1. Создание namespace
echo "[1/6] Создание namespace '$NAMESPACE'..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# 2. Создание секретов из текущих .env
echo "[2/6] Создание секретов..."

# Читаем пароли из .env
source ../.env

kubectl create secret generic ess-secrets -n $NAMESPACE \
  --from-literal=postgres-password="${POSTGRES_PASSWORD}" \
  --from-literal=synapse-postgres-password="${POSTGRES_PASSWORD}" \
  --from-literal=mas-client-secret="SynapseClientSecret123!" \
  --from-literal=livekit-api-key="${LIVEKIT_API_KEY}" \
  --from-literal=livekit-api-secret="${LIVEKIT_API_SECRET}" \
  --dry-run=client -o yaml | kubectl apply -f -

# 3. Копирование Synapse signing key (если есть)
echo "[3/6] Извлечение Synapse signing key..."
if docker exec matrix-synapse test -f /data/gigglin.tech.signing.key 2>/dev/null; then
    SIGNING_KEY=$(docker exec matrix-synapse cat /data/gigglin.tech.signing.key)
    kubectl create secret generic synapse-signing-key -n $NAMESPACE \
      --from-literal=signing.key="$SIGNING_KEY" \
      --dry-run=client -o yaml | kubectl apply -f -
    echo "Signing key скопирован из текущего Synapse"
else
    echo "Signing key не найден, будет создан новый (потребуется миграция устройств)"
fi

# 4. Добавление Helm репозитория
echo "[4/6] Добавление Element Helm репозитория..."
helm repo add ess https://element-hq.github.io/ess-helm 2>/dev/null || true
helm repo update

# 5. Проверка values.yaml
echo "[5/6] Проверка конфигурации..."
if [ ! -f "./03-ess-values.yaml" ]; then
    echo "ОШИБКА: Файл 03-ess-values.yaml не найден!"
    exit 1
fi

# 6. Установка ESS Helm chart
echo "[6/6] Установка Element Server Suite..."
echo "Это может занять несколько минут..."

helm upgrade --install matrix-stack ess/element-server-suite \
  --namespace $NAMESPACE \
  --values ./03-ess-values.yaml \
  --timeout 10m \
  --wait

echo ""
echo "=== Проверка развёртывания ==="
kubectl get pods -n $NAMESPACE

echo ""
echo "=== Следующие шаги ==="
echo "1. Дождитесь статуса Running для всех pods:"
echo "   kubectl get pods -n $NAMESPACE -w"
echo ""
echo "2. Проверьте логи Synapse:"
echo "   kubectl logs -n $NAMESPACE -l app=synapse -f"
echo ""
echo "3. Настройте NPM Proxy Hosts для новых сервисов:"
echo "   - app.gigglin.tech -> K8s NodePort для element-web"
echo "   - call.gigglin.tech -> K8s NodePort для element-call"
echo ""
echo "4. Получите NodePort сервисов:"
echo "   kubectl get svc -n $NAMESPACE"
