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

# 1.1 Создание секретов (из .env или дефолтные)
echo "[1.1/5] Настройка секретов..."
if [ -f ".env" ]; then
    source .env
    echo "Загружены переменные из .env"
else
    echo "ВНИМАНИЕ: .env не найден, используются дефолтные пароли!"
    POSTGRES_PASSWORD="changeme"
    SYNAPSE_SIGNING_KEY="generate_me_please"
    MAS_CLIENT_SECRET="SynapseClientSecret123!"
    LIVEKIT_API_KEY="matrix-rtc"
    LIVEKIT_API_SECRET="secret"
fi

# Генерация ключей если не заданы
if [ "$SYNAPSE_SIGNING_KEY" = "generate_me_please" ]; then
    SYNAPSE_SIGNING_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
fi

# Создание ess-secrets
kubectl create secret generic ess-secrets -n $NAMESPACE \
  --from-literal=postgres-password="$POSTGRES_PASSWORD" \
  --from-literal=synapse-postgres-password="$POSTGRES_PASSWORD" \
  --from-literal=mas-client-secret="$MAS_CLIENT_SECRET" \
  --from-literal=livekit-api-key="$LIVEKIT_API_KEY" \
  --from-literal=livekit-api-secret="$LIVEKIT_API_SECRET" \
  --from-literal=signing.key="$SYNAPSE_SIGNING_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Секреты созданы/обновлены в namespace $NAMESPACE"

# 2. Создание директории конфигурации
echo "[2/5] Создание директории конфигурации..."
mkdir -p ~/ess-config-values

# 3. Создание конфигурационного файла
echo "[3/3] Создание values.yaml..."
echo "Используется встроенный PostgreSQL из ESS"
cat > ~/ess-config-values/ess-values.yaml <<EOF
# Element Server Suite Community Configuration
# Дата: $(date +%Y-%m-%d)

# Global settings
serverName: "$SERVER_NAME"

# Используем встроенный PostgreSQL
postgres:
  enabled: true

# Synapse Configuration
synapse:
  enabled: true
  
  ingress:
    host: "matrix.$SERVER_NAME"
    tlsEnabled: false  # TLS terminates at NPM

# Matrix Authentication Service
matrixAuthenticationService:
  enabled: true
  
  ingress:
    host: "auth.$SERVER_NAME"
    tlsEnabled: false  # TLS terminates at NPM

# Matrix RTC (для звонков)
matrixRTC:
  enabled: true
  
  # URL для внутренней коммуникации Authorization Service -> SFU
  # ВАЖНО: должен быть ВНУТРЕННИЙ адрес, не внешний HTTPS
  livekit_url: "ws://ess-matrix-rtc-sfu.ess.svc.cluster.local:7880"
  
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

# 4. Установка ESS через OCI registry
echo "[4/4] Установка Element Server Suite Community..."
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
echo "4. Создание первого пользователя (admin):"
echo "   Попытка автоматического создания пользователя admin..."
    
# Ожидание готовности MAS
kubectl wait --for=condition=Available deployment/ess-matrix-authentication-service -n $NAMESPACE --timeout=300s

if kubectl exec -n $NAMESPACE deployment/ess-matrix-authentication-service -- mas-cli manage register-user --yes -p 'changeme123' -a admin; then
    echo "✅ Пользователь 'admin' создан (пароль: changeme123)"
else
    echo "⚠️ Не удалось создать пользователя (возможно уже существует)"
fi

echo ""
echo "5. Протестируйте на https://app.$SERVER_NAME"
echo ""
echo "Просмотр логов:"
echo "   kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=synapse -f"
echo "   kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=matrix-authentication-service -f"
echo "   kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=matrix-rtc -f"
