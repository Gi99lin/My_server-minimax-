#!/bin/bash
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=== Принудительное пересоздание Authorization Service Pod ==="
echo ""

# Получить текущий pod
OLD_POD=$(kubectl get pods -n ess -l app.kubernetes.io/name=matrix-rtc-authorisation-service -o jsonpath='{.items[0].metadata.name}')
echo "Текущий pod: $OLD_POD"
echo ""

# Удалить pod
echo "Удаляю pod..."
kubectl delete pod -n ess $OLD_POD

# Ждать появления нового пода
echo "Ожидание нового пода..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=matrix-rtc-authorisation-service -n ess --timeout=60s

# Получить новый pod
NEW_POD=$(kubectl get pods -n ess -l app.kubernetes.io/name=matrix-rtc-authorisation-service -o jsonpath='{.items[0].metadata.name}')
echo ""
echo "✅ Новый pod: $NEW_POD"
echo ""

# Проверить переменные через describe
echo "Проверка переменных окружения в новом pod:"
kubectl describe pod -n ess $NEW_POD | grep -A 10 "Environment:"
echo ""

echo "=========================================="
echo "СЛЕДУЮЩИЙ ШАГ:"
echo "=========================================="
echo ""
echo "1. Hard refresh браузера (Ctrl+Shift+R)"
echo "2. Начни новый звонок"
echo "3. Проверь Network → /sfu/get Response"
echo ""
echo "Должно быть: \"url\": \"wss://sfu.gigglin.tech\""
echo ""
