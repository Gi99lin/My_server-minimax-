#!/bin/bash
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=== Создание ExternalName Service для sfu.gigglin.tech ==="
echo ""
echo "ПРОБЛЕМА: Authorization Service не поддерживает отдельный PUBLIC_URL"
echo "Он возвращает клиентам тот же URL который использует сам (LIVEKIT_URL)"
echo ""
echo "РЕШЕНИЕ: Сделать wss://sfu.gigglin.tech доступным изнутри K8s"
echo "через DNS резолв на внешний IP + NPM proxy"
echo ""

# Создать Service типа ExternalName
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: sfu-external
  namespace: ess
spec:
  type: ExternalName
  externalName: sfu.gigglin.tech
  ports:
  - port: 443
    targetPort: 443
    protocol: TCP
    name: https
EOF

echo "✅ ExternalName Service создан"
echo ""

# Теперь изменить LIVEKIT_URL на wss://sfu.gigglin.tech
echo "Патчинг Authorization Service..."
cat > /tmp/livekit-external-url-patch.yaml <<EOF
spec:
  template:
    spec:
      containers:
      - name: matrix-rtc-authorisation-service
        env:
        - name: LIVEKIT_URL
          value: "wss://sfu.gigglin.tech"
        - name: LIVEKIT_KEY
          value: "matrix-rtc"
        - name: LIVEKIT_SECRET_FROM_FILE
          value: "/secrets/ess-generated/ELEMENT_CALL_LIVEKIT_SECRET"
        - name: LIVEKIT_FULL_ACCESS_HOMESERVERS
          value: "gigglin.tech"
EOF

kubectl patch deployment -n ess ess-matrix-rtc-authorisation-service \
  --patch-file /tmp/livekit-external-url-patch.yaml

echo "Перезапуск..."
kubectl rollout restart deployment/ess-matrix-rtc-authorisation-service -n ess
kubectl rollout status deployment/ess-matrix-rtc-authorisation-service -n ess

echo ""
echo "=== Настройка .well-known для RTC ==="
echo "Обновляем client config в .well-known, чтобы клиенты знали куда стучаться (mrtc.$DOMAIN)"

# Получаем текущий конфиг, патчим JSON с помощью jq и загружаем обратно
# Устанавливаем livekit_service_url и auth issuer
kubectl get cm -n ess ess-well-known-haproxy -o json | \
  jq ".data.client = \"{\\\"m.homeserver\\\":{\\\"base_url\\\":\\\"https://matrix.gigglin.tech\\\"},\\\"org.matrix.msc2965.authentication\\\":{\\\"account\\\":\\\"https://auth.gigglin.tech/account\\\",\\\"issuer\\\":\\\"https://auth.gigglin.tech/\\\"},\\\"org.matrix.msc4143.rtc_foci\\\":[{\\\"livekit_service_url\\\":\\\"https://mrtc.gigglin.tech\\\",\\\"type\\\":\\\"livekit\\\"}]}\"" | \
  kubectl replace -f -

echo "Перезапуск HAProxy для применения..."
kubectl rollout restart deployment/ess-haproxy -n ess
kubectl rollout status deployment/ess-haproxy -n ess

echo ""
echo "✅ .well-known обновлен"

echo ""
echo "✅ ПРИМЕНЕНО"
echo ""
echo "=========================================="
echo "АРХИТЕКТУРА:"
echo "=========================================="
echo ""
echo "1. Client запрашивает JWT:"
echo "   POST https://mrtc.gigglin.tech/sfu/get"
echo ""
echo "2. Authorization Service создает комнату на SFU:"
echo "   POST wss://sfu.gigglin.tech → NPM → 172.18.0.1:30780"
echo "   (через внешний прокси с TLS)"
echo ""
echo "3. Authorization Service отвечает:"
echo '   { "url": "wss://sfu.gigglin.tech", "token": "..." }'
echo ""
echo "4. Client подключается к SFU:"
echo "   WebSocket wss://sfu.gigglin.tech → NPM → SFU"
echo ""
echo "=========================================="
echo ""
echo "Hard refresh браузера и начни звонок!"
echo ""
