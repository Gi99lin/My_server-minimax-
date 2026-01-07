#!/bin/bash
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=== Исправление livekit_service_url ==="
echo ""
echo "ПРОБЛЕМА: livekit_service_url указывает на SFU вместо Authorization Service"
echo ""
echo "Клиент делает:"
echo "  POST wss://sfu.gigglin.tech/sfu/get ❌ (неверно)"
echo ""
echo "Должно быть:"
echo "  POST https://mrtc.gigglin.tech/sfu/get ✅ (Authorization Service)"
echo "  WebSocket: wss://sfu.gigglin.tech/rtc ✅ (SFU, автоматически)"
echo ""

# Патчим .well-known обратно на mrtc.gigglin.tech
echo "[1/3] Обновление .well-known..."

kubectl get cm -n ess ess-well-known-haproxy -o json | \
  jq '.data.client = "{\"m.homeserver\":{\"base_url\":\"https://matrix.gigglin.tech\"},\"org.matrix.msc2965.authentication\":{\"account\":\"https://auth.gigglin.tech/account\",\"issuer\":\"https://auth.gigglin.tech/\"},\"org.matrix.msc4143.rtc_foci\":[{\"livekit_service_url\":\"https://mrtc.gigglin.tech\",\"type\":\"livekit\"}]}"' | \
  kubectl replace -f -

echo "[2/3] Перезапуск HAProxy..."
kubectl rollout restart deployment/ess-haproxy -n ess
kubectl rollout status deployment/ess-haproxy -n ess
echo ""

sleep 3

echo "[3/3] Проверка обновленного .well-known:"
curl -s https://gigglin.tech/.well-known/matrix/client | jq .
echo ""

echo "✅ ИСПРАВЛЕНО"
echo ""
echo "=========================================="
echo "АРХИТЕКТУРА:"
echo "=========================================="
echo ""
echo "1. Клиент запрашивает JWT:"
echo "   POST https://mrtc.gigglin.tech/sfu/get"
echo "   → Authorization Service (30880)"
echo ""
echo "2. Authorization Service создает комнату на SFU:"
echo "   POST ws://ess-matrix-rtc-sfu.ess.svc.cluster.local:7880/rtc/..."
echo "   → LiveKit SFU (internal)"
echo ""
echo "3. Authorization Service отвечает клиенту с URL SFU:"
echo "   { \"url\": \"wss://sfu.gigglin.tech\", \"token\": \"...\" }"
echo ""
echo "4. Клиент подключается к SFU:"
echo "   WebSocket wss://sfu.gigglin.tech/rtc?access_token=..."
echo "   → LiveKit SFU (30780)"
echo ""
echo "=========================================="
echo ""
echo "Теперь начни звонок в Element Web"
echo ""
