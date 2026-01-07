# Конфигурация Nginx Proxy Manager для ESS

## Сначала добавь DNS записи (timeweb.cloud):

```
app.gigglin.tech     A    37.60.251.4
admin.gigglin.tech   A    37.60.251.4
```

## Создание Proxy Hosts в NPM (http://37.60.251.4:81)

### 1. gigglin.tech (корень - .well-known)

**Details:**
- Domain: `gigglin.tech`
- Scheme: `http`
- Forward Hostname: `localhost`
- Forward Port: `32393`
- ✅ Block Common Exploits
- ✅ Websockets Support

**SSL:**
- ✅ Request SSL Certificate (Let's Encrypt)
- ✅ HTTP/2 Support
- ✅ HSTS Enabled
- ❌ Force SSL (отключить на время валидации, потом можно включить)

**Custom Locations:**
- Location: `/`
- Config:
```nginx
add_header Access-Control-Allow-Origin *;
```

---

### 2. matrix.gigglin.tech

**Details:**
- Domain: `matrix.gigglin.tech`
- Forward: `localhost:31435`
- ✅ Block Common Exploits
- ✅ Websockets Support

**SSL:**
- ✅ Request SSL Certificate
- ✅ Force SSL
- ✅ HTTP/2
- ✅ HSTS

**Custom Config:** НЕТ (пусто)

---

### 3. auth.gigglin.tech

**Details:**
- Domain: `auth.gigglin.tech`
- Forward: `localhost:32534`
- ✅ Block Common Exploits
- ✅ Websockets Support

**SSL:**
- ✅ Request SSL Certificate
- ✅ Force SSL
- ✅ HTTP/2
- ✅ HSTS

**Custom Config:** НЕТ

---

### 4. app.gigglin.tech

**Details:**
- Domain: `app.gigglin.tech`
- Forward: `localhost:31056`
- ✅ Block Common Exploits
- ✅ Websockets Support

**SSL:**
- ✅ Request SSL Certificate
- ✅ Force SSL
- ✅ HTTP/2
- ✅ HSTS

**Custom Config:** НЕТ

---

### 5. admin.gigglin.tech

**Details:**
- Domain: `admin.gigglin.tech`
- Forward: `localhost:31419`
- ✅ Block Common Exploits
- ✅ Websockets Support

**SSL:**
- ✅ Request SSL Certificate
- ✅ Force SSL
- ✅ HTTP/2
- ✅ HSTS

**Custom Config:** НЕТ

---

## Важно для WebRTC Calling:

Эти порты НЕ проксируются через NPM, а должны быть открыты напрямую:

```bash
# Проверить открыты ли порты
ss -tlnp | grep 30881
ss -ulnp | grep 30882
```

- **30881/TCP** - Matrix RTC TCP (для WebRTC signaling)
- **30882/UDP** - Matrix RTC UDP (для медиа-трафика)

Если не слушают - порты доступны через NodePort автоматически.
