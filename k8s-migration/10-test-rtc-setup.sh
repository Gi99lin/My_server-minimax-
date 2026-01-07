#!/bin/bash
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=== Диагностика RTC конфигурации ==="
echo ""

# 1. Проверяем .well-known - что видят клиенты
echo "[1] .well-known/matrix/client (что видят клиенты):"
curl -s https://gigglin.tech/.well-known/matrix/client | jq .
echo ""

# 2. Проверяем что находится на sfu.gigglin.tech
echo "[2] Проверка sfu.gigglin.tech (должен быть LiveKit SFU):"
curl -s https://sfu.gigglin.tech/ || echo "Пустой ответ - норма для LiveKit"
echo ""

# 3. Проверяем что находится на mrtc.gigglin.tech
echo "[3] Проверка mrtc.gigglin.tech (должен быть Authorization Service):"
curl -s https://mrtc.gigglin.tech/ || echo "404 - норма для auth service"
echo ""

# 4. Получаем текущие значения LIVEKIT_URL из Authorization Service
echo "[4] LIVEKIT_URL в Authorization Service deployment:"
kubectl get deployment -n ess ess-matrix-rtc-authorisation-service -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="LIVEKIT_URL")].value}'
echo ""
echo ""

# 5. Проверяем внутренний SFU
echo "[5] Внутренний LiveKit SFU (ClusterIP):"
kubectl get svc -n ess ess-matrix-rtc-sfu -o wide
echo ""

# 6. Проверяем Authorization Service
echo "[6] Authorization Service (NodePort):"
kubectl get svc -n ess ess-matrix-rtc-authorisation-service -o wide
echo ""

echo "=========================================="
echo "АНАЛИЗ:"
echo "=========================================="
echo ""
echo "Ошибка: Fetch API cannot load wss://sfu.gigglin.tech/sfu/get"
echo ""
echo "Проблема: Клиент использует wss:// для HTTP endpoint /sfu/get"
echo ""
echo "ВОЗМОЖНЫЕ ПРИЧИНЫ:"
echo "1. .well-known указывает на sfu.gigglin.tech вместо mrtc.gigglin.tech"
echo "2. Клиент неправильно интерпретирует livekit_service_url"
echo ""
echo "ОЖИДАЕМОЕ ПОВЕДЕНИЕ:"
echo "- JWT auth: POST https://mrtc.gigglin.tech/sfu/get (HTTP)"
echo "- Media WebSocket: wss://sfu.gigglin.tech/rtc (WSS)"
echo ""
