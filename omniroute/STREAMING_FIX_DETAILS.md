# Анализ и исправление стриминга в OmniRoute (v3.0.x)

## 1. Суть проблемы (Context)
Библиотека **OpenAI Python SDK** (используемая в вашем бекенде) при `stream=True` отправляет заголовок:
`Accept: application/json, text/event-stream`

В ядре OmniRoute функция `resolveStreamFlag` (файл `src/open-sse/utils/aiSdkCompat.ts`) считала, что если в заголовке есть `application/json`, то приоритет отдается синхронному ответу, даже если клиент явно попросил стрим.

## 2. Логика исправления (Logic)
Мы изменили приоритеты в файле `src/open-sse/utils/aiSdkCompat.ts`. Теперь **явный параметр `stream: true` в JSON-теле запроса имеет абсолютный приоритет** над любыми заголовками `Accept`.

### Код исправления:
```typescript
export function resolveStreamFlag(bodyStream: unknown, acceptHeader: unknown): boolean {
  // ПРИОРИТЕТ: Если в теле запроса есть stream=true, всегда стримим.
  if (bodyStream === true || bodyStream === "true") return true;

  // FALLBACK: Если в теле ничего нет, смотрим на заголовки Accept.
  return !clientWantsJsonResponse(acceptHeader) && 
         String(acceptHeader || "").toLowerCase().includes("text/event-stream");
}
```

## 3. Особенности Docker (`standalone` mode)
OmniRoute собран в режиме `standalone`. Это значит, что Docker-образ содержит **пре-компилированный JS-код**. 
**Важно:** Простое изменение `.ts` файлов в папке `src` на хосте ничего не даст, так как контейнер запускает код из папки `.next`. 
**Решение:** Всегда пересобирать образ после правок:
`docker compose build omniroute && docker compose up -d`

## 4. Настройка Nginx (Nginx Proxy Manager)
Для корректной передачи потока данных (SSE) без задержек и буферизации, в настройках прокси (Nginx) должны быть установлены следующие параметры:

```nginx
proxy_buffering off;
proxy_request_buffering off;
proxy_read_timeout 600s;
tcp_nodelay on;
proxy_set_header X-Accel-Buffering no;
proxy_cache off;
```

## 5. Дополнительные правки
- **Regex Fix**: В функции `stripMarkdownCodeFence` исправлена опечатка в регулярном выражении (четыре кавычки заменены на три), чтобы корректно извлекать JSON из ответов Claude/Thinking моделей.
- **Backend Sync**: В `ai_service.py` вашего бэкенда добавлена поддержка `reasoning_content` для вывода процесса «размышления» модели.

---

## Update: Official Fix in v3.1.4

As of 2026-03-27, an official fix has been released in **OmniRoute v3.1.4** (Streaming Override Fix). 
The fix ensures that a `stream: true` parameter in the request body correctly overrides conflicting `Accept` headers, providing the same behavior as this manual patch but natively supported by the project.

**Recommendation:** Update the deployment to `v3.1.4` or later and revert these manual changes using `git reset --hard` in the `src` directory before pulling the update.
