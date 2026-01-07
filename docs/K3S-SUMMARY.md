# Element Server Suite на K3s - Итоговая Документация

## 🎯 Финальный Статус

**✅ Element Server Suite Community полностью функционален на gigglin.tech**

- Сервер: 37.60.251.4
- K3s версия: v1.31.4+k3s1
- ESS версия: Helm chart oci://ghcr.io/element-hq/ess-helm/matrix-stack

### Работающие Компоненты

- ✅ Matrix Synapse homeserver (matrix.gigglin.tech)
- ✅ Matrix Authentication Service OAuth2 (auth.gigglin.tech)
- ✅ Element Web client (app.gigglin.tech)
- ✅ Element Admin console (admin.gigglin.tech)
- ✅ .well-known delegation (gigglin.tech)
- ✅ LiveKit SFU для звонков (sfu.gigglin.tech)
- ✅ RTC Authorization Service (mrtc.gigglin.tech)
- ✅ PostgreSQL база данных (встроенная)
- ✅ HAProxy internal routing

### Проверенная Функциональность

- ✅ Регистрация и аутентификация пользователей
- ✅ E2E зашифрованные сообщения
- ✅ Создание комнат и приглашения
- ✅ **Голосовые звонки (1:1 и групповые)**
- ✅ **Видео звонки (1:1 и групповые)**
- ✅ Federation discovery (.well-known)

---

## 📋 Архитектура

### Сетевая Топология

```
Internet (HTTPS)
      ↓
Nginx Proxy Manager (Docker: 172.18.0.1)
      ↓
K3s NodePorts (Host Network)
      ↓
K8s Services (ClusterIP)
      ↓
Pods (ess namespace)
```

### Критичные Детали

**NPM Proxy Hosts ОБЯЗАТЕЛЬНО используют `172.18.0.1`**

Причина: NPM в Docker, K3s на хосте - разные network namespaces.
`localhost` в NPM резолвится в NPM контейнер, а не в K3s хост.

### Домены и Маршрутизация

| Домен | NPM → | K3s NodePort | K8s Service | Назначение |
|-------|-------|--------------|-------------|-----------|
| matrix.gigglin.tech | 172.18.0.1:31435 | 31435 | ess-synapse-main | Homeserver API |
| auth.gigglin.tech | 172.18.0.1:32534 | 32534 | ess-matrix-authentication-service | OAuth2/OIDC |
| app.gigglin.tech | 172.18.0.1:31056 | 31056 | ess-element-web | Web Client |
| admin.gigglin.tech | 172.18.0.1:31419 | 31419 | ess-element-admin | Admin Console |
| gigglin.tech | 172.18.0.1:32393 | 32393 | ess-haproxy | .well-known |
| mrtc.gigglin.tech | 172.18.0.1:30880 | 30880 | ess-matrix-rtc-authorisation-service | RTC JWT |
| sfu.gigglin.tech | 172.18.0.1:30780 | 30780 | ess-matrix-rtc-sfu | LiveKit Media |

### SSL/TLS

- **Внешний слой (NPM)**: Полный SSL/TLS с Let's Encrypt, Force SSL enabled
- **Внутренний слой (K8s)**: HTTP без TLS (TLS termination на NPM)
- WebSockets: Enabled на всех proxy hosts (особенно критично для `sfu.gigglin.tech`)

---

## 🔧 RTC Calling - Критичное Решение

### Проблема

Authorization Service не поддерживает отдельный `LIVEKIT_PUBLIC_URL`. Он возвращает клиентам тот же URL что использует сам (`LIVEKIT_URL`).

Первоначально Authorization Service использовал внутренний URL:
```
LIVEKIT_URL=ws://ess-matrix-rtc-sfu.ess.svc.cluster.local:7880
```

Возвращал клиентам:
```json
{
  "url": "ws://ess-matrix-rtc-sfu.ess.svc.cluster.local:7880",
  "jwt": "..."
}
```

Браузер блокировал: `Mixed Content Error - insecure WebSocket from HTTPS page`

### Решение

**Использовать публичный URL (`wss://sfu.gigglin.tech`) как для Authorization Service, так и для клиентов.**

1. Создан ExternalName Service для резолва `sfu.gigglin.tech` внутри K8s
2. Authorization Service подключается к SFU через NPM: `wss://sfu.gigglin.tech`
3. Возвращает клиентам тот же публичный URL: `wss://sfu.gigglin.tech`

### Реализация

Файл: [`k8s-migration/17-create-external-sfu-service.sh`](17-create-external-sfu-service.sh)

```bash
# ExternalName Service
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
    protocol: TCP
    name: https

# Authorization Service Environment
LIVEKIT_URL=wss://sfu.gigglin.tech
```

### Поток Данных RTC Звонка

1. **Client → Authorization Service**
   ```
   POST https://mrtc.gigglin.tech/sfu/get
   Headers: Authorization: Bearer <matrix_openid_token>
   ```

2. **Authorization Service → SFU (room creation)**
   ```
   POST wss://sfu.gigglin.tech
   → NPM (TLS termination)
   → 172.18.0.1:30780
   → K3s NodePort
   → LiveKit SFU pod
   ```

3. **Authorization Service → Client (response)**
   ```json
   {
     "url": "wss://sfu.gigglin.tech",
     "jwt": "eyJhbGc..."
   }
   ```

4. **Client → SFU (media connection)**
   ```
   WebSocket wss://sfu.gigglin.tech/rtc?access_token=<jwt>
   → NPM
   → SFU pod
   → WebRTC media streams (UDP)
   ```

---

## 📦 Установка с Нуля

### 1. Подготовка Сервера

```bash
# K3s
curl -sfL https://get.k3s.io | sh -

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# kubectl config
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> ~/.bashrc
```

### 2. Развертывание ESS

```bash
git clone <repo>
cd My_server/k8s-migration

chmod +x 06-deploy-ess-community.sh
./06-deploy-ess-community.sh
```

### 3. Настройка NPM Proxy Hosts

**КРИТИЧНО**: Все upstream hosts = `172.18.0.1`, а НЕ `localhost`

Для каждого домена:
- SSL: ✅ Force SSL, HTTP/2, HSTS
- WebSockets: ✅ (для matrix, mrtc, sfu)
- Блокировка эксплойтов: ✅

### 4. Исправление RTC

```bash
chmod +x 17-create-external-sfu-service.sh
./17-create-external-sfu-service.sh
```

### 5. Создание Пользователей

```bash
kubectl exec -n ess deployment/ess-matrix-authentication-service -- \
  mas-cli manage register-user --yes -p 'Password123' -a admin

kubectl exec -n ess deployment/ess-matrix-authentication-service -- \
  mas-cli manage register-user --yes -p 'Password123' username
```

---

## 🐛 Траблшутинг

### Проверка Здоровья Системы

```bash
# Поды
kubectl get pods -n ess
# Все должны быть Running

# Сервисы
kubectl get svc -n ess
# Проверить NodePort маппинг

# Логи Synapse
kubectl logs -n ess -l app.kubernetes.io/name=synapse-main -f

# Логи RTC
kubectl logs -n ess -l app.kubernetes.io/name=matrix-rtc-sfu -f
kubectl logs -n ess -l app.kubernetes.io/name=matrix-rtc-authorisation-service -f
```

### .well-known Валидация

```bash
curl https://gigglin.tech/.well-known/matrix/client
```

Должен вернуть:
```json
{
  "m.homeserver": {"base_url": "https://matrix.gigglin.tech"},
  "org.matrix.msc2965.authentication": {
    "account": "https://auth.gigglin.tech/account",
    "issuer": "https://auth.gigglin.tech/"
  },
  "org.matrix.msc4143.rtc_foci": [{
    "livekit_service_url": "https://mrtc.gigglin.tech",
    "type": "livekit"
  }]
}
```

### NPM 502 Bad Gateway

Причина: Upstream host = `localhost` вместо `172.18.0.1`

Решение: Изменить все NPM proxy hosts на Docker bridge IP

### RTC Mixed Content Error

Браузер блокирует `ws://` с HTTPS страницы.

**НЕ РЕШЕНИЕ**: Добавлять переменную `LIVEKIT_PUBLIC_URL` (игнорируется)

**РЕШЕНИЕ**: Изменить `LIVEKIT_URL` на публичный `wss://` URL

### Звонки не соединяются

```bash
# Проверить SFU логи
kubectl logs -n ess -l app.kubernetes.io/name=matrix-rtc-sfu -f

# Во время звонка должны появиться:
# - CreateRoom
# - ParticipantJoined
# - TrackPublished
```

Если CreateRoom есть, но TrackPublished нет - firewall блокирует UDP порты.

---

## 🚀 Производственная Настройка

### UDP Buffer для LiveKit

```bash
sudo sysctl -w net.core.rmem_max=5000000
echo "net.core.rmem_max=5000000" | sudo tee -a /etc/sysctl.conf
```

### Resource Limits (рекомендуется)

```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
```

### Backup PostgreSQL

```bash
kubectl exec -n ess ess-postgres-0 -c postgres -- \
  pg_dump -U synapse synapse > backup-$(date +%Y%m%d).sql
```

---

## 📌 Важные Ссылки

- ESS Helm Chart: https://github.com/element-hq/ess-helm
- K3s Docs: https://docs.k3s.io
- Matrix Spec: https://spec.matrix.org
- LiveKit Docs: https://docs.livekit.io
- MSC4143 (Native RTC): https://github.com/matrix-org/matrix-spec-proposals/pull/4143

---

## 🎓 Уроки

1. **Network Namespace Isolation**: Docker и K3s имеют разные сетевые стеки
2. **Authorization Service Limitation**: Не поддерживает separate public URL
3. **ExternalName Services**: Позволяют K8s подам резолвить внешние домены
4. **TLS Termination**: NPM = HTTPS, K8s internal = HTTP
5. **WebSocket Support**: Критично для Matrix и RTC
6. **Mixed Content Policy**: Браузер блокирует ws:// с https://

---

Создано: 2026-01-08  
Автор: Claude 4 Sonnet (Kilo Code)  
VPS: 37.60.251.4 (gigglin.tech)
