#!/bin/bash
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=== Разделение RTC на 2 домена ==="
echo ""
echo "mrtc.gigglin.tech → Authorization Service (JWT auth)"
echo "sfu.gigglin.tech → LiveKit SFU (WebSocket media)"
echo ""

# 1. Проверим текущее содержимое .well-known
echo "[1/4] Текущий .well-known/matrix/client:"
kubectl exec -n ess deployment/ess-haproxy -- curl -s http://localhost:8010/.well-known/matrix/client | jq .
echo ""

# 2. Патчим ConfigMap с новым livekit_service_url
echo "[2/4] Обновление .well-known в HAProxy ConfigMap..."

# Получаем текущий ConfigMap и обновляем только нужное поле
kubectl get cm -n ess ess-well-known-haproxy -o json | \
  jq '.data.client = "{\"m.homeserver\":{\"base_url\":\"https://matrix.gigglin.tech\"},\"org.matrix.msc2965.authentication\":{\"account\":\"https://auth.gigglin.tech/account\",\"issuer\":\"https://auth.gigglin.tech/\"},\"org.matrix.msc4143.rtc_foci\":[{\"livekit_service_url\":\"wss://sfu.gigglin.tech\",\"type\":\"livekit\"}]}"' | \
  kubectl replace -f -

# 3. Перезапуск HAProxy для применения изменений
echo "[3/4] Перезапуск HAProxy..."
kubectl rollout restart deployment/ess-haproxy -n ess
kubectl rollout status deployment/ess-haproxy -n ess
echo ""

# Ждем пару секунд
sleep 3

# 4. Проверяем новый .well-known
echo "[4/4] Проверка обновленного .well-known:"
kubectl exec -n ess deployment/ess-haproxy -- curl -s http://localhost:8010/.well-known/matrix/client | jq .
echo ""

echo "✅ .well-known обновлён"
echo ""

# Получить NodePort LiveKit SFU
SFU_NODEPORT=$(kubectl get svc -n ess ess-matrix-rtc-sfu -o jsonpath='{.spec.ports[0].nodePort}')
echo "LiveKit SFU NodePort: $SFU_NODEPORT"
echo ""

# Инструкции для DNS и NPM
echo "=========================================="
echo "НЕОБХОДИМЫЕ ДЕЙСТВИЯ:"
echo "=========================================="
echo ""
echo "1. ДОБАВЬ DNS ЗАПИСЬ:"
echo "   ----------------------------"
echo "   Имя: sfu"
echo "   Тип: A"
echo "   Значение: 37.60.251.4"
echo "   TTL: 300"
echo ""
echo "2. СОЗДАЙ NPM PROXY HOST:"
echo "   ----------------------------"
echo "   Domain Names: sfu.gigglin.tech"
echo "   Scheme: http"
echo "   Forward Hostname/IP: 172.18.0.1"
echo "   Forward Port: $SFU_NODEPORT"
echo ""
echo "   SSL Certificate:"
echo "     ✅ Force SSL"
echo "     ✅ HTTP/2 Support"
echo "     ✅ HSTS Enabled"
echo "     ✅ Request a new SSL Certificate"
echo ""
echo "   Advanced:"
echo "     ✅ Websockets Support (КРИТИЧНО!)"
echo "     ✅ Block Common Exploits"
echo ""
echo "3. ПРОВЕРЬ СУЩЕСТВУЮЩИЙ NPM:"
echo "   ----------------------------"
echo "   mrtc.gigglin.tech → 172.18.0.1:30880"
echo "   (должен остаться на Authorization Service)"
echo ""
echo "=========================================="
echo ""
echo "После настройки NPM проверь:"
echo ""
echo "  curl https://gigglin.tech/.well-known/matrix/client | jq"
echo ""
echo "Должно быть:"
echo '  "livekit_service_url": "wss://sfu.gigglin.tech"'
echo ""
echo "Затем начни звонок в Element Web/X"
echo ""
