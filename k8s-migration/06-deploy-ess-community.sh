#!/bin/bash

# Скрипт развёртывания Element Server Suite Community
# Основан на официальной документации: https://github.com/element-hq/ess-helm

set -e

NAMESPACE="ess"
SERVER_NAME="gigglin.tech"

echo "=== Развёртывание Element Server Suite Community ==="

# 1. Создание namespace
echo "[1/7] Создание namespace '$NAMESPACE'..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# 2. Создание директории конфигурации
echo "[2/7] Создание директории конфигурации..."
mkdir -p ~/ess-config-values

# 3. Скачивание fragment для hostnames
echo "[3/7] Скачивание конфигурации hostnames..."
curl -L https://raw.githubusercontent.com/element-hq/ess-helm/refs/heads/main/charts/matrix-stack/ci/fragments/quick-setup-hostnames.yaml -o ~/ess-config-values/hostnames.yaml

# 4. Настройка hostnames
echo "[4/7] Настройка доменных имён..."
cat > ~/ess-config-values/hostnames.yaml <<EOF
# Element Server Suite Community - Hostnames Configuration
# Domain: gigglin.tech

# Global domain settings
global:
  serverName: "$SERVER_NAME"

# Synapse homeserver
synapse:
  ingress:
    host: "matrix.$SERVER_NAME"

# Matrix Authentication Service
matrixAuthenticationService:
  ingress:
    host: "auth.$SERVER_NAME"

# Matrix RTC Backend (для звонков)
matrixRtcBackend:
  enabled: true
  ingress:
    host: "mrtc.$SERVER_NAME"

# Element Web (веб-клиент)
elementWeb:
  enabled: true
  ingress:
    host: "app.$SERVER_NAME"

# Element Admin (админ-панель)
elementAdmin:
  enabled: true
  ingress:
    host: "admin.$SERVER_NAME"

# .well-known delegation
wellKnown:
  enabled: true
  ingress:
    host: "$SERVER_NAME"
EOF

# 5. Конфигурация TLS (отключаем, используем NPM)
echo "[5/7] Настройка TLS (external proxy mode)..."
curl -L https://raw.githubusercontent.com/element-hq/ess-helm/refs/heads/main/charts/matrix-stack/ci/fragments/quick-setup-external-cert.yaml -o ~/ess-config-values/tls.yaml

# 6. Использование внешнего PostgreSQL
echo "[6/7] Конфигурация внешнего PostgreSQL..."
# Читаем пароль из .env
if [ -f ".env" ]; then
    source .env
elif [ -f "../.env" ]; then
    source ../.env
else
    echo "ОШИБКА: Файл .env не найден!"
    exit 1
fi

cat > ~/ess-config-values/postgresql.yaml <<EOF
# External PostgreSQL configuration

# Отключаем встроенный PostgreSQL
postgresql:
  enabled: false

# Настройки подключения для Synapse
synapse:
  config:
    database:
      name: synapse
      host: host.docker.internal  # K3s -> Docker host
      port: 5432
      user: matrix
      password: "${POSTGRES_PASSWORD}"

# Настройки подключения для MAS
matrixAuthenticationService:
  config:
    database:
      uri: "postgresql://matrix:${POSTGRES_PASSWORD}@host.docker.internal:5432/mas"
EOF

# 7. Установка ESS через OCI registry
echo "[7/7] Установка Element Server Suite Community..."
echo "Это может занять 5-10 минут..."

helm upgrade --install --namespace "$NAMESPACE" ess \
  oci://ghcr.io/element-hq/ess-helm/matrix-stack \
  -f ~/ess-config-values/hostnames.yaml \
  -f ~/ess-config-values/tls.yaml \
  -f ~/ess-config-values/postgresql.yaml \
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
echo "   kubectl get svc -n $NAMESPACE | grep NodePort"
echo ""
echo "3. Настройте NPM Proxy Hosts:"
echo "   - matrix.$SERVER_NAME -> localhost:[synapse-nodeport]"
echo "   - auth.$SERVER_NAME -> localhost:[mas-nodeport]"
echo "   - app.$SERVER_NAME -> localhost:[element-web-nodeport]"
echo "   - admin.$SERVER_NAME -> localhost:[element-admin-nodeport]"
echo "   - mrtc.$SERVER_NAME -> localhost:[mrtc-nodeport]"
echo "   - $SERVER_NAME -> localhost:[wellknown-nodeport]"
echo ""
echo "4. Создайте первого пользователя:"
echo "   kubectl exec -n $NAMESPACE -it deploy/ess-matrix-authentication-service -- mas-cli manage register-user"
echo ""
echo "5. Протестируйте на https://app.$SERVER_NAME"
