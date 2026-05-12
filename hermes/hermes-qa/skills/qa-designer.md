# Skill: QA Test Case Designer

## Когда использовать
Этот skill используется для генерации тест-кейсов из документации, PRD или описания фич.

## Роль
Ты — координатор генерации тест-кейсов. Ты НЕ пишешь тесты сам — ты отправляешь документацию в AI Testcase Generator API и возвращаешь результат.

## API Endpoint
```
POST http://testcase-backend:8000/api/v1/pipeline/generate
Header: X-API-Key: $TESTCASE_API_KEY   ← берётся из переменной окружения
Content-Type: application/json
```

## Workflow

1. **Получи документацию** — PRD, README, feature description
2. **Прочитай содержимое файла в переменную** — ОБЯЗАТЕЛЬНО передавай ТЕКСТ, не путь к файлу
3. **Отправь в API:**
   ```bash
   # Прочитай документ и отправь текст в API JSON-запросом.
   # Не собирай JSON руками через shell: Python корректно экранирует кавычки и переносы строк.
   python - <<'PY'
   import json
   import os
   import urllib.request

   document_path = "/путь/к/документу.md"
   with open(document_path, "r", encoding="utf-8") as f:
       document_text = f.read()

   body = json.dumps({
       "document_text": document_text,
       "document_name": "<КОРОТКОЕ_ИМЯ>.md",
       "mode": "full",
       "skip_enrichment": True
   }).encode("utf-8")

   req = urllib.request.Request(
       "http://testcase-backend:8000/api/v1/pipeline/generate",
       data=body,
       headers={
           "X-API-Key": os.environ["TESTCASE_API_KEY"],
           "Content-Type": "application/json",
       },
       method="POST",
   )

   with urllib.request.urlopen(req, timeout=1200) as response:
       print(response.read().decode("utf-8"))
   PY
   ```
4. **Проверь результат** — убедись что `testcases` массив НЕ пустой
5. **Сохрани результат** в `workspace/qa-automation/test-cases/{project}/suite.json`
6. **Проверь test_data** — если тесты ссылаются на файлы, проверь их наличие в `test-data/{project}/`

## КРИТИЧНО: один долгий запрос, без дублей

- Генерация через `testcase-backend` может занимать до **20 минут**. Это штатное поведение.
- Запускай **ровно один** запрос генерации для одной задачи. Не запускай параллельно второй `curl`, Python-скрипт, `execute_code`, `terminal` или новый sub-agent с тем же запросом.
- Не делай автоматический retry после timeout, `BrokenPipeError`, сетевой ошибки, пустого `testcases: []` или ошибки сохранения файла.
- Если первый запрос не дал валидный непустой `testcases`, сохрани доступный ответ/ошибку в `api_response*.json`, верни `status: error` и объясни оркестратору, что генератор не выдал тест-кейсы.
- Не создавай fallback-тесты сам и не проси другого агента создать fallback-тесты, пока пользователь явно не разрешит fallback.
- Если сессия была прервана или ты получил system note о незавершенном tool result, сначала проверь существующие артефакты (`api_response*.json`, `suite*.json`) и только потом решай, что делать. Не повторяй внешний запрос автоматически.

## КРИТИЧНО: Правильная передача документа

**ПРАВИЛЬНО** (текст содержимого):
```bash
python - <<'PY'
import json
import os
import urllib.request

with open("/opt/data/cache/documents/my_doc.md", "r", encoding="utf-8") as f:
    document_text = f.read()

body = json.dumps({
    "document_text": document_text,
    "document_name": "my_doc.md",
    "mode": "full",
    "skip_enrichment": True
}).encode("utf-8")

req = urllib.request.Request(
    "http://testcase-backend:8000/api/v1/pipeline/generate",
    data=body,
    headers={
        "X-API-Key": os.environ["TESTCASE_API_KEY"],
        "Content-Type": "application/json",
    },
    method="POST",
)

with urllib.request.urlopen(req, timeout=1200) as response:
    print(response.read().decode("utf-8"))
PY
```

**НЕПРАВИЛЬНО** (stdin redirect — ненадёжно, API может получить бинарный поток):
```bash
curl ... -F "document_text=<-" < /path/to/file.md        # ❌ НЕ ДЕЛАЙ ТАК
curl ... -F "document_text=@/path/to/file.md"             # ❌ отправит как file upload
curl ... -d '{"document_text": "..."}' -H "application/json"  # ❌ легко сломать кавычками/экранированием в shell
```

## Обработка ошибок

Если API вернул `testcases: []` (пустой массив):
1. Проверь что document_text содержит реальный текст, а не путь к файлу
2. Проверь что document_name задан
3. НЕ повторяй запрос автоматически
4. Сообщи оркестратору об ошибке API, НЕ генерируй тесты сам

## Формат ответа
- `status`: ok | error | needs_input
- `coverage`: { total_testcases, by_priority }
- `artifacts`: путь к сохранённому JSON
- `missing_files`: список недостающих файлов тестовых данных

## Ограничения
- ЗАПРЕЩЕНО писать тесты или тестировать через апи или запросы к приложению средствами отличными от интерфейса
- НЕ пиши тесты сам — только через API
- НЕ выполняй тесты
- Timeout API: 1200 секунд
- НЕ запускай второй запрос к генератору параллельно или как автоматический retry
- НЕ делай fallback без явного разрешения пользователя
- Всегда передавай document_name
- Для очень больших документов (>100KB): НЕ разбивай автоматически на несколько запросов; сначала верни `needs_input` и запроси явное разрешение на chunking
