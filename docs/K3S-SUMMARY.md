# Element Server Suite на K3s - Итоговая Документация (v2.0)

## 🎯 Статус Системы (2026-01-08)

**✅ Все компоненты полностью функциональны:**
- **Регистрация пользователей:** Работает (через Element Web и MAS)
- **Звонки (RTC):** Работают (1:1 и конференц-звонки)
- **Федерация:** Работает (.well-known настроен)

---

## 🛠 Критические Настройки (Как это работает)

### 1. Архитектура Сети (Network Topology)

Это самый важный аспект. Из-за того, что NPM работает в Docker, а K3s на хосте, маршрутизация устроена так:

```mermaid
graph TD
    Client[Client] -->|HTTPS/WSS| NPM[Nginx Proxy Manager <br> (Docker: Public IP)]
    NPM -->|Bridge IP: 172.18.0.1| K3s[K3s NodePorts <br> (Host Interface)]
    K3s -->|Service Selector| Pods[Matrix Pods]
```

**КЛЮЧЕВОЕ ПРАВИЛО:** NPM должен проксировать на **`172.18.0.1`**, а не на `localhost` или публичный IP.

### 2. Настройка Звонков (RTC / LiveKit)

Для работы звонков необходимы **NodePort сервисы** с правильными селекторами.

#### NodePort Конфигурация
| Сервис | Порт (Internal) | NodePort (External) | Selector (Критично!) |
|--------|-----------------|---------------------|----------------------|
| **Authorization** | 8080 | **30880** | `app.kubernetes.io/name: your_livekit_api_key_here-authorisation-service` |
| **LiveKit SFU** | 7880 | **30780** | `app.kubernetes.io/name: your_livekit_api_key_here-sfu` |

#### NPM Прокси Хосты
*   **mrtc.gigglin.tech** (Auth Service)
    *   Forward Host: `172.18.0.1`
    *   Forward Port: `30880`
    *   Schemes: HTTP, WS Support: On
*   **sfu.gigglin.tech** (Media/SFU)
    *   Forward Host: `172.18.0.1`
    *   Forward Port: **`30780`**
    *   Schemes: HTTP, **WS Support: ON (Обязательно!)**

> ⚠️ **Важно:** Если селекторы сервиса не совпадают с лейблами подов, endpoints будут пустыми, и iptables правила не создадутся (ошибка Connection Refused).

### 3. Настройка Регистрации

Регистрация требует двух изменений в `ess-values.yaml`:

1. **Включить в MAS (Authentication Service):**
   ```yaml
   matrixAuthenticationService:
     additional:
       enable-registration:
         config: |
           passwords:
             enabled: true
           account:
             password_registration_enabled: true  # <--- ВКЛЮЧИТЬ ЭТО
   ```

2. **Включить кнопку в Element Web:**
   ```yaml
   elementWeb:
     additional:
       setting_defaults: '{"UIFeature.registration": true}'
   ```

---

## 📝 Инструкция по Восстановлению (Если всё сломалось)

Если вам придется переустанавливать сервер, следуйте этим шагам, чтобы сразу получить рабочий результат.

### Шаг 1: Установка K3s и ESS
Используйте стандартные скрипты установки.

### Шаг 2: Создание NodePort для RTC
Helm chart не создает нужные NodePort'ы по умолчанию (или создает на случайных портах). Создайте их вручную скриптом:

```yaml
# auth-nodeport.yaml
apiVersion: v1
kind: Service
metadata:
  name: ess-your_livekit_api_key_here-authorisation-service-nodeport
  namespace: ess
spec:
  type: NodePort
  ports:
  - name: http
    port: 8080
    targetPort: 8080
    nodePort: 30880
  selector:
    app.kubernetes.io/instance: ess-your_livekit_api_key_here-authorisation-service
    app.kubernetes.io/name: your_livekit_api_key_here-authorisation-service
---
# sfu-nodeport.yaml
apiVersion: v1
kind: Service
metadata:
  name: ess-your_livekit_api_key_here-sfu-nodeport-http
  namespace: ess
spec:
  type: NodePort
  ports:
  - name: http
    port: 7880
    targetPort: 7880
    nodePort: 30780
  selector:
    app.kubernetes.io/instance: ess-your_livekit_api_key_here-sfu
    app.kubernetes.io/name: your_livekit_api_key_here-sfu
```

### Шаг 3: Настройка NPM
Настройте все домены (`matrix`, `auth`, `app`, `mrtc`, `sfu`) на IP **`172.18.0.1`**.

| Домен | Порт | Заметки |
|-------|------|---------|
| matrix | 31435 | Synapse |
| auth | 32534 | MAS |
| app | 31056 | Element Web |
| mrtc | 30880 | Auth Service (CORS OK) |
| sfu | 30780 | SFU (WebSockets Critical) |

### Шаг 4: Проверка
```bash
# Проверка mrtc (должен 405)
curl -I https://mrtc.gigglin.tech/sfu/get

# Проверка sfu (должен 200)
curl -I https://sfu.gigglin.tech
```

---

## 🐛 Известные Проблемы и Решения

**1. 502 Bad Gateway на RTC доменах**
*   **Причина:** NPM ломится на внешний IP, или нет iptables правил.
*   **Решение:** Поменять IP в NPM на `172.18.0.1`. Проверить NodePort сервисы и их селекторы.

**2. Connection Refused на 172.18.0.1:30880**
*   **Причина:** Неверные селекторы в Service. Endpoints пусты.
*   **Решение:** Проверить `kubectl get endpoints -n ess`. Если пусто — исправить селектор в yaml сервиса.

**3. Кнопка регистрации не работает / "Registration disabled"**
*   **Причина:** MAS config не применился.
*   **Решение:** Проверить `ess-values.yaml`, применить `helm upgrade`, перезапустить MAS pod (`kubectl delete pod ...`).
