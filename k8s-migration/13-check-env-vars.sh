#!/bin/bash
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=== Проверка переменных Authorization Service ==="
echo ""

echo "Все переменные окружения:"
kubectl get deployment -n ess ess-matrix-rtc-authorisation-service \
  -o jsonpath='{.spec.template.spec.containers[0].env[*].name}' | \
  tr ' ' '\n'
echo ""
echo ""

echo "LIVEKIT_URL:"
kubectl get deployment -n ess ess-matrix-rtc-authorisation-service \
  -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="LIVEKIT_URL")].value}'
echo ""
echo ""

echo "LIVEKIT_PUBLIC_URL:"
kubectl get deployment -n ess ess-matrix-rtc-authorisation-service \
  -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="LIVEKIT_PUBLIC_URL")].value}' || echo "(не установлено)"
echo ""
echo ""

echo "=========================================="
echo "Если LIVEKIT_PUBLIC_URL не установлен:"
echo "Запусти: ./k8s-migration/12-set-public-livekit-url.sh"
echo ""
echo "Если установлен, но клиент все еще видит ws://"
echo "то проблема в Element Web - проверь Network вкладку"
echo "=========================================="
