#!/bin/bash

# Скрипт патча LIVEKIT_URL через kubectl patch
# Проблема: Helm chart не поддерживает livekit_url parameter
# Решение: Прямой patch Deployment через kubectl

set -e

# Настройка окружения K3s
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

NAMESPACE="ess"
SERVER_NAME="gigglin.tech"
INTERNAL_SFU_URL="ws://ess-matrix-rtc-sfu.ess.svc.cluster.local:7880"

echo "=== Исправление LIVEKIT_URL через kubectl patch ==="
echo ""
echo "Текущая проблема:"
kubectl describe deployment -n $NAMESPACE ess-matrix-rtc-authorisation-service | grep "LIVEKIT_URL"
echo ""
echo "Должно быть: $INTERNAL_SFU_URL"
echo ""

# 1. Создаём patch файл
echo "[1/3] Создание patch файла..."
cat > /tmp/livekit-url-patch.yaml <<EOF
spec:
  template:
    spec:
      containers:
      - name: matrix-rtc-authorisation-service
        env:
        - name: LIVEKIT_URL
          value: "$INTERNAL_SFU_URL"
        - name: LIVEKIT_KEY
          value: "matrix-rtc"
        - name: LIVEKIT_SECRET_FROM_FILE
          value: "/secrets/ess-generated/ELEMENT_CALL_LIVEKIT_SECRET"
        - name: LIVEKIT_FULL_ACCESS_HOMESERVERS
          value: "$SERVER_NAME"
EOF

echo "Patch файл создан"
echo ""

# 2. Применение patch
echo "[2/3] Применение patch к Deployment..."
kubectl patch deployment -n $NAMESPACE ess-matrix-rtc-authorisation-service \
  --patch-file /tmp/livekit-url-patch.yaml

echo ""
echo "Patch применён"
echo ""

# 3. Ожидание rollout
echo "[3/3] Ожидание перезапуска пода..."
kubectl rollout status deployment/ess-matrix-rtc-authorisation-service -n $NAMESPACE

echo ""
echo "=== Проверка результата ==="
echo ""
kubectl describe deployment -n $NAMESPACE ess-matrix-rtc-authorisation-service | grep -A 5 "Environment:"

echo ""
echo "✅ LIVEKIT_URL обновлён!"
echo ""

# 4. Опциональное включение регистрации
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
    echo "Создание ConfigMap патча для MAS..."
    
    # Получаем текущий config.yaml из MAS ConfigMap
    kubectl get cm -n $NAMESPACE ess-matrix-authentication-service -o jsonpath='{.data.config\.yaml}' > /tmp/mas-config-current.yaml
    
    echo "Текущий config.yaml сохранён в /tmp/mas-config-current.yaml"
    echo ""
    
    # Создаём новый config с включенной регистрацией
    cat > /tmp/mas-config-patched.yaml <<EOF
# Matrix Authentication Service Configuration
# Patched: $(date '+%Y-%m-%d %H:%M:%S')

# OAuth клиенты
clients:
  - client_id: 0000000000000000000SYNAPSE
    client_auth_method: client_secret_basic
    client_secret: SynapseSuperSecret

# Upstream issuer
upstream:
  issuer: https://auth.$SERVER_NAME/

# HTTP listeners
http:
  listeners:
    - name: web
      resources:
        - name: discovery
        - name: human
        - name: oauth
        - name: compat
        - name: graphql
          playground: true
        - name: assets
      binds:
        - address: "[::]:8080"

# Email настройки (Yandex SMTP)
email:
  from: "$SMTP_FROM_NAME <$SMTP_FROM_EMAIL>"
  reply_to: "$SMTP_FROM_EMAIL"
  transport: smtp
  hostname: $SMTP_HOST
  port: $SMTP_PORT
  mode: starttls
  username: $SMTP_USERNAME
  password: $SMTP_PASSWORD

# Matrix homeserver
matrix:
  homeserver: matrix.$SERVER_NAME
  endpoint: http://ess-synapse.ess.svc.cluster.local:8008
  secret: SynapseSuperSecret

# Password схемы
passwords:
  enabled: true
  schemes:
    - version: 1
      algorithm: argon2id

# ВКЛЮЧАЕМ РЕГИСТРАЦИЮ
account:
  registration:
    enabled: true
    require_email_verification: true
    
# Database
database:
  uri: env://MAS_DATABASE_URL

# Secrets (будут загружены из environment)
secrets:
  encryption: env://MAS_ENCRYPTION_KEY
  keys:
    - kid: primary
      key: env://MAS_SIGNING_KEY
EOF

    echo "Применение нового config.yaml к MAS..."
    kubectl create cm -n $NAMESPACE ess-matrix-authentication-service-patched \
      --from-file=config.yaml=/tmp/mas-config-patched.yaml \
      --dry-run=client -o yaml | \
      kubectl apply -f -
    
    # Обновляем deployment чтобы использовать новый ConfigMap
    kubectl set env deployment/ess-matrix-authentication-service -n $NAMESPACE --from=configmap/ess-matrix-authentication-service-patched
    
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
echo "2. Начни звонок между двумя пользователями"
echo "3. Смотри логи Authorization Service:"
echo ""
echo "   kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=matrix-rtc-authorisation-service -f"
echo ""
echo "Ожидается что теперь создание комнаты на SFU пройдёт успешно!"
echo ""
