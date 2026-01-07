#!/bin/bash

# Скрипт исправления LIVEKIT_URL в Authorization Service
# Проблема: Authorization Service использовал внешний HTTPS URL (wss://mrtc.gigglin.tech)
# Решение: Переключить на внутренний ClusterIP (ws://ess-matrix-rtc-sfu.ess.svc.cluster.local:7880)

set -e

# Настройка окружения K3s
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

NAMESPACE="ess"
SERVER_NAME="gigglin.tech"

echo "=== Исправление LIVEKIT_URL для Matrix RTC ==="
echo ""
echo "Проблема: Authorization Service идёт через внешний HTTPS URL к SFU"
echo "Решение: Использовать внутренний ClusterIP адрес"
echo ""

# 1. Обновление values.yaml
echo "[1/2] Обновление конфигурации..."
cat > ~/ess-config-values/ess-values.yaml <<EOF
# Element Server Suite Community Configuration
# Обновлено: $(date '+%Y-%m-%d %H:%M:%S')

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

echo "Конфигурация обновлена"
echo ""

# 2. Применение обновления через Helm
echo "[2/2] Применение изменений через Helm upgrade..."
echo "Это займёт 1-2 минуты..."
echo ""

helm upgrade \
  --namespace "$NAMESPACE" \
  ess \
  oci://ghcr.io/element-hq/ess-helm/matrix-stack \
  -f ~/ess-config-values/ess-values.yaml \
  --wait \
  --timeout 5m

echo ""
echo "=== Обновление завершено! ==="
echo ""

# 3. Проверка deployment
echo "Проверка Authorization Service deployment:"
kubectl describe deployment -n $NAMESPACE ess-matrix-rtc-authorisation-service | grep -A 5 "Environment:"

echo ""
echo "Ожидается:"
echo "  LIVEKIT_URL: ws://ess-matrix-rtc-sfu.ess.svc.cluster.local:7880"
echo ""

# 4. Ждём готовности пода
echo "Ожидание готовности нового пода Authorization Service..."
kubectl rollout status deployment/ess-matrix-rtc-authorisation-service -n $NAMESPACE

echo ""
echo "✅ LIVEKIT_URL исправлен!"
echo ""

# 5. Включение публичной регистрации через MAS
echo "=== [ОПЦИОНАЛЬНО] Включение публичной регистрации ==="
echo ""
read -p "Включить публичную регистрацию через веб-интерфейс? (y/N): " ENABLE_REG

if [[ "$ENABLE_REG" =~ ^[Yy]$ ]]; then
    echo ""
    echo "Загрузка .env для SMTP настроек..."
    
    # Проверка наличия .env файла
    if [ -f "/root/vps-server/.env" ]; then
        source /root/vps-server/.env
    else
        echo "⚠️  .env не найден, используем значения по умолчанию"
        SMTP_HOST="smtp.yandex.ru"
        SMTP_PORT="587"
        SMTP_USERNAME="gi99lin@yandex.ru"
        SMTP_PASSWORD="rjxhcdyyvgcjqqvd"
        SMTP_FROM_EMAIL="gi99lin@yandex.ru"
        SMTP_FROM_NAME="gigglin.tech"
    fi
    
    echo ""
    echo "Патчим ConfigMap MAS для включения регистрации и email..."
    
    # Получаем существующий ConfigMap
    kubectl get cm -n $NAMESPACE ess-matrix-authentication-service -o yaml > /tmp/mas-cm-backup.yaml
    
    # Создаём патч для включения регистрации
    kubectl patch cm -n $NAMESPACE ess-matrix-authentication-service --type merge -p '{
      "data": {
        "config.yaml": "# Matrix Authentication Service Configuration\n# Auto-patched for registration + SMTP\n\nclients:\n  - client_id: 0000000000000000000SYNAPSE\n    client_auth_method: client_secret_basic\n    client_secret: SynapseSuperSecret  # Должен совпадать с Synapse\n\nupstream:\n  issuer: https://auth.'"$SERVER_NAME"'/\n\nhttp:\n  listeners:\n    - name: web\n      resources:\n        - name: discovery\n        - name: human\n        - name: oauth\n        - name: compat\n        - name: graphql\n          playground: true\n        - name: assets\n      binds:\n        - address: \"[::]:8080\"\n\nemail:\n  from: \"'"$SMTP_FROM_NAME"' <'"$SMTP_FROM_EMAIL"'>\"\n  reply_to: \"'"$SMTP_FROM_EMAIL"'\"\n  transport: smtp\n  hostname: '"$SMTP_HOST"'\n  port: '"$SMTP_PORT"'\n  mode: starttls\n  username: '"$SMTP_USERNAME"'\n  password: '"$SMTP_PASSWORD"'\n\nmatrix:\n  homeserver: matrix.'"$SERVER_NAME"'\n  endpoint: http://ess-synapse.ess.svc.cluster.local:8008\n  secret: SynapseSuperSecret\n\npasswords:\n  enabled: true\n  schemes:\n    - version: 1\n      algorithm: argon2id\n\naccount:\n  # ВКЛЮЧАЕМ ПУБЛИЧНУЮ РЕГИСТРАЦИЮ\n  registration:\n    enabled: true\n    # Требовать подтверждение email\n    require_email_verification: true\n    \ndatabase:\n  uri: postgresql://mas:${MAS_DB_PASSWORD}@ess-postgres.ess.svc.cluster.local:5432/mas\n\nsecrets:\n  encryption: ${MAS_ENCRYPTION_KEY}\n  keys:\n    - kid: ${MAS_SIGNING_KEY_KID}\n      key: ${MAS_SIGNING_KEY}\n"
      }
    }'
    
    echo ""
    echo "Перезапуск MAS для применения изменений..."
    kubectl rollout restart deployment/ess-matrix-authentication-service -n $NAMESPACE
    kubectl rollout status deployment/ess-matrix-authentication-service -n $NAMESPACE
    
    echo ""
    echo "✅ Регистрация включена!"
    echo ""
    echo "Теперь пользователи могут:"
    echo "1. Открыть https://app.$SERVER_NAME"
    echo "2. Нажать 'Create account'"
    echo "3. Заполнить форму регистрации"
    echo "4. Подтвердить email (письмо придёт с $SMTP_FROM_EMAIL)"
    echo ""
else
    echo "Пропускаем включение регистрации"
    echo ""
    echo "Для создания пользователей вручную используй:"
    echo "  kubectl exec -n $NAMESPACE deployment/ess-matrix-authentication-service -- \\"
    echo "    mas-cli manage register-user --yes -p 'Password123' -a username"
    echo ""
fi

echo "=== Финальная проверка ==="
echo ""
echo "Теперь протестируй звонок:"
echo "1. Открой https://app.$SERVER_NAME"
echo "2. Начни звонок между пользователями"
echo "3. Смотри логи:"
echo ""
echo "   kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=matrix-rtc-authorisation-service -f"
echo ""
