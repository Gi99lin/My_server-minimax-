#!/bin/bash
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=== Попытка альтернативных переменных ==="
echo ""
echo "LIVEKIT_PUBLIC_URL установлен, но игнорируется"
echo "Попробуем другие названия переменной..."
echo ""

# Патч с несколькими вариантами названий
cat > /tmp/livekit-alternative-env-patch.yaml <<EOF
spec:
  template:
    spec:
      containers:
      - name: matrix-rtc-authorisation-service
        env:
        - name: LIVEKIT_URL
          value: "wss://sfu.gigglin.tech"
        - name: LIVEKIT_PUBLIC_URL
          value: "wss://sfu.gigglin.tech"
        - name: PUBLIC_LIVEKIT_URL
          value: "wss://sfu.gigglin.tech"
        - name: LIVEKIT_WS_URL
          value: "wss://sfu.gigglin.tech"
        - name: LIVEKIT_KEY
          value: "matrix-rtc"
        - name: LIVEKIT_SECRET_FROM_FILE
          value: "/secrets/ess-generated/ELEMENT_CALL_LIVEKIT_SECRET"
        - name: LIVEKIT_FULL_ACCESS_HOMESERVERS
          value: "gigglin.tech"
EOF

echo "[1/3] Патчинг с альтернативными названиями..."
kubectl patch deployment -n ess ess-matrix-rtc-authorisation-service \
  --patch-file /tmp/livekit-alternative-env-patch.yaml

echo "[2/3] Ожидание перезапуска..."
kubectl rollout status deployment/ess-matrix-rtc-authorisation-service -n ess

# Принудительное удаление pod
echo "[3/3] Принудительное пересоздание pod..."
kubectl delete pod -n ess -l app.kubernetes.io/name=matrix-rtc-authorisation-service
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=matrix-rtc-authorisation-service -n ess --timeout=60s

echo ""
echo "✅ ПРИМЕНЕНО"
echo ""
echo "=========================================="
echo "ИЗМЕНЕНИЕ:"
echo "=========================================="
echo ""
echo "Теперь LIVEKIT_URL = wss://sfu.gigglin.tech (публичный)"
echo ""
echo "ВНИМАНИЕ: Сервер БОЛЬШЕ НЕ сможет создавать комнаты на SFU!"
echo "Потому что он будет пытаться подключиться к wss:// а не ws://"
echo ""
echo "Если /sfu/get все еще отдает ws:// -"
echo "значит Authorization Service hardcoded использует LIVEKIT_URL"
echo "и не поддерживает отдельный public URL."
echo ""
echo "В этом случае нужно искать другое решение..."
echo ""
