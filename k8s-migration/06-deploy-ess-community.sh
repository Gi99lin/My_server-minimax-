#!/bin/bash

# Скрипт развёртывания Element Server Suite Community
# Основан на официальной документации: https://github.com/element-hq/ess-helm

set -e

NAMESPACE="ess"
SERVER_NAME="gigglin.tech"

echo "=== Развёртывание Element Server Suite Community ==="

# 1. Создание namespace
echo "[1/5] Создание namespace '$NAMESPACE'..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# 2. Создание директории конфигурации
echo "[2/5] Создание директории конфигурации..."
mkdir -p ~/ess-config-values

# 3. Чтение пароля PostgreSQL
echo "[3/5] Чтение пароля PostgreSQL..."
if [ -f ".env" ]; then
    source .env
elif [ -f "../.env" ]; then
    source ../.env
else
    echo "ОШИБКА: Файл .env не найден!"
    exit 1
fi

# 4. Создание конфигурационного файла
echo "[4/5] Создание values.yaml..."
cat > ~/ess-config-values/ess-values.yaml <<EOF
# Element Server Suite Community Configuration
# Дата: $(date +%Y-%m-%d)

# Global settings
serverName: "$SERVER_NAME"

# Отключаем встроенный PostgreSQL (используем внешний Docker)
postgres:
  enabled: false

# Synapse Configuration
synapse:
  enabled: true
  
  # Внешний PostgreSQL
  postgres:
    host: "host.docker.internal"
    port: 5432
    database: synapse
    user: matrix
    password:
      value: "${POSTGRES_PASSWORD}"
  
  ingress:
    host: "matrix.$SERVER_NAME"
    tlsEnabled: false  # TLS terminates at NPM

# Matrix Authentication Service
matrixAuthenticationService:
  enabled: true
  
  # Внешний PostgreSQL
  postgres:
    host: "host.docker.internal"
    port: 5432
    database: mas
    user: matrix
    password:
      value: "${POSTGRES_PASSWORD}"
  
  ingress:
    host: "auth.$SERVER_NAME"
    tlsEnabled: false  # TLS terminates at NPM

# Matrix RTC (для звонков)
matrixRTC:
  enabled: true
  
  ingress:
    host: "mrtc.$SERVER_NAME"
    tlsEnabled: false  # TLS terminates at NPM
  
  # Встроенный LiveKit SFU
  sfu:
    enabled: true
    useStunToDiscoverPublicIP: true

# Element Web
elementWeb:
  enabled: true
  
  ingress:
    host: "app.$SERVER_NAME"
    tlsEnabled: false  # TLS terminates at NPM

# Element Admin
elementAdmin:
  enabled: true
  
  ingress:
    host: "admin.$SERVER_NAME"
    tlsEnabled: false  # TLS terminates at NPM

# .well-known delegation
wellKnownDelegation:
  enabled: true
  
  ingress:
    tlsEnabled: false  # TLS terminates at NPM

# HAProxy (internal routing)
haproxy:
  replicas: 1

# Отключаем TLS на всех Ingress (NPM терминирует SSL)
ingress:
  tlsEnabled: false
  # Используем NodePort вместо ClusterIP для доступа извне
  service:
    type: NodePort
EOF

echo ""
echo "Конфигурация сохранена в ~/ess-config-values/ess-values.yaml"

# 5. Установка ESS через OCI registry
echo "[5/5] Установка Element Server Suite Community..."
echo "Это может занять 5-10 минут..."

helm upgrade --install \
  --namespace "$NAMESPACE" \
  --create-namespace \
  ess \
  oci://ghcr.io/element-hq/ess-helm/matrix-stack \
  -f ~/ess-config-values/ess-values.yaml \
  --wait \
  --timeout 15m

echo ""
echo "=== Развёртывание завершено! ==="
echo ""
echo "Проверка состояния pods:"
kubectl get pods -n $NAMESPACE

echo ""
echo "=== Следующие шаги ==="
echo ""
echo "1. Дождитесь статуса Running для всех pods:"
echo "   kubectl get pods -n $NAMESPACE -w"
echo ""
echo "2. Получите NodePorts сервисов:"
echo "   kubectl get svc -n $NAMESPACE"
echo ""
echo "3. Настройте NPM Proxy Hosts для каждого сервиса:"
echo "   - matrix.$SERVER_NAME -> localhost:[synapse-nodeport]"
echo "   - auth.$SERVER_NAME -> localhost:[mas-nodeport]"
echo "   - app.$SERVER_NAME -> localhost:[element-web-nodeport]"
echo "   - admin.$SERVER_NAME -> localhost:[element-admin-nodeport]"
echo "   - mrtc.$SERVER_NAME -> localhost:[mrtc-nodeport]"
echo "   - $SERVER_NAME -> localhost:[wellknown-nodeport]"
echo ""
echo "4. Создайте первого пользователя:"
echo "   kubectl exec -n $NAMESPACE -it deploy/ess-synapse -- register_new_matrix_user -c /data/homeserver.yaml http://localhost:8008"
echo ""
echo "5. Протестируйте на https://app.$SERVER_NAME"
echo ""
echo "Просмотр логов:"
echo "   kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=synapse -f"
echo "   kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=matrix-authentication-service -f"
echo "   kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=matrix-rtc -f"
