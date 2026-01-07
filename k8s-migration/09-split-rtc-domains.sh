#!/bin/bash
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=== Разделение RTC на 2 домена ==="
echo ""
echo "mrtc.gigglin.tech → Authorization Service (JWT auth)"
echo "sfu.gigglin.tech → LiveKit SFU (WebSocket media)"
echo ""

# 1. Патч .well-known для использования sfu.gigglin.tech
echo "[1/3] Обновление .well-known/matrix/client..."

kubectl patch cm -n ess ess-well-known-delegation --type merge -p '{
  "data": {
    "client": "{\"m.homeserver\":{\"base_url\":\"https://matrix.gigglin.tech\"},\"org.matrix.msc2965.authentication\":{\"account\":\"https://auth.gigglin.tech/account\",\"issuer\":\"https://auth.gigglin.tech/\"},\"org.matrix.msc4143.rtc_foci\":[{\"livekit_service_url\":\"wss://sfu.gigglin.tech\",\"type\":\"livekit\"}]}"
  }
}'

kubectl rollout restart deployment/ess-well-known-delegation -n ess
kubectl rollout status deployment/ess-well-known-delegation -n ess

echo ""
echo "✅ .well-known обновлён: livekit_service_url = wss://sfu.gigglin.tech"
echo ""

# 2. Получить NodePort LiveKit SFU
SFU_NODEPORT=$(kubectl get svc -n ess ess-matrix-rtc-sfu -o jsonpath='{.spec.ports[0].nodePort}')
echo "[2/3] LiveKit SFU NodePort: $SFU_NODEPORT"
echo ""

# 3. Инструкция для NPM и DNS
echo "[3/3] Необходимые действия:"
echo ""
echo "=========================================="
echo "1. ДОБАВЬ DNS ЗАПИСЬ:"
echo "=========================================="
echo "   Имя: sfu"
echo "   Тип: A"
echo "   Значение: 37.60.251.4"
echo "   TTL: 300"
echo ""
echo "=========================================="
echo "2. СОЗДАЙ NPM PROXY HOST:"
echo "=========================================="
echo "   Domain Names: sfu.gigglin.tech"
echo "   Scheme: http"
echo "   Forward Hostname/IP: 172.18.0.1"
echo "   Forward Port: $SFU_NODEPORT"
echo ""
echo "   SSL Certificate:"
echo "     ✅ Force SSL"
echo "     ✅ HTTP/2 Support"
echo "     ✅ HSTS Enabled"
echo "     ✅ Request a new SSL Certificate (Let's Encrypt)"
echo ""
echo "   Advanced:"
echo "     ✅ Websockets Support (ВАЖНО!)"
echo "     ✅ Block Common Exploits"
echo ""
echo "=========================================="
echo "3. ПРОВЕРЬ СУЩЕСТВУЮЩИЙ NPM PROXY:"
echo "=========================================="
echo "   mrtc.gigglin.tech должен остаться на порту 30880"
echo "   (Authorization Service для /sfu/get endpoint)"
echo ""
echo "=========================================="
echo ""

echo "После настройки NPM протестируй:"
echo ""
echo "  # Проверь .well-known"
echo "  curl https://gigglin.tech/.well-known/matrix/client | jq"
echo ""
echo "  # Должно быть: \"livekit_service_url\": \"wss://sfu.gigglin.tech\""
echo ""
echo "  # Проверь WebSocket доступность (после получения SSL)"
echo "  wscat -c wss://sfu.gigglin.tech/rtc"
echo ""
echo "Затем начни звонок в Element Web"
echo ""
