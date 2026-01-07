#!/bin/bash
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=== Настройка LIVEKIT_PUBLIC_URL ==="
echo ""
echo "ПРОБЛЕМА: Authorization Service возвращает внутренний URL клиентам"
echo "  ws://ess-matrix-rtc-sfu.ess.svc.cluster.local:7880"
echo ""
echo "РЕШЕНИЕ: Добавить LIVEKIT_PUBLIC_URL=wss://sfu.gigglin.tech"
echo ""

# Патчим Deployment с LIVEKIT_PUBLIC_URL
cat > /tmp/livekit-public-url-patch.yaml <<EOF
spec:
  template:
    spec:
      containers:
      - name: matrix-rtc-authorisation-service
        env:
        - name: LIVEKIT_URL
          value: "ws://ess-matrix-rtc-sfu.ess.svc.cluster.local:7880"
        - name: LIVEKIT_PUBLIC_URL
          value: "wss://sfu.gigglin.tech"
        - name: LIVEKIT_KEY
          value: "matrix-rtc"
        - name: LIVEKIT_SECRET_FROM_FILE
          value: "/secrets/ess-generated/ELEMENT_CALL_LIVEKIT_SECRET"
        - name: LIVEKIT_FULL_ACCESS_HOMESERVERS
          value: "gigglin.tech"
EOF

echo "[1/2] Патчинг Authorization Service Deployment..."
kubectl patch deployment -n ess ess-matrix-rtc-authorisation-service \
  --patch-file /tmp/livekit-public-url-patch.yaml

echo "[2/2] Ожидание перезапуска..."
kubectl rollout status deployment/ess-matrix-rtc-authorisation-service -n ess
echo ""

echo "✅ НАСТРОЕНО"
echo ""
echo "=========================================="
echo "ПРОВЕРКА:"
echo "=========================================="
echo ""
kubectl get deployment -n ess ess-matrix-rtc-authorisation-service \
  -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="LIVEKIT_PUBLIC_URL")].value}'
echo " ← LIVEKIT_PUBLIC_URL"
echo ""
echo "Теперь Authorization Service будет отвечать клиентам:"
echo '  { "url": "wss://sfu.gigglin.tech", "token": "..." }'
echo ""
echo "Начни новый звонок в Element Web"
echo ""
