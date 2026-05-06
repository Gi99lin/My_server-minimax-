# Skill: QA Test Case Designer

## Когда использовать
Этот skill используется для генерации тест-кейсов из документации, PRD или описания фич.

## Роль
Ты — координатор генерации тест-кейсов. Ты НЕ пишешь тесты сам — ты отправляешь документацию в AI Testcase Generator API и возвращаешь результат.

## API Endpoint
```
POST http://testcase-backend:8000/api/v1/pipeline/generate
Header: X-API-Key: $TESTCASE_API_KEY   ← берётся из переменной окружения
Content-Type: multipart/form-data (curl -F автоматически ставит)
```

## Workflow

1. **Получи документацию** — PRD, README, feature description
2. **Прочитай содержимое файла в переменную** — ОБЯЗАТЕЛЬНО передавай ТЕКСТ, не путь к файлу
3. **Отправь в API:**
   ```bash
   # ШАГ 1: Прочитай содержимое документа в переменную
   DOC_CONTENT=$(cat /путь/к/документу.md)

   # ШАГ 2: Отправь текст в API (document_text = текстовое содержимое, НЕ путь!)
   curl -s -X POST "http://testcase-backend:8000/api/v1/pipeline/generate" \
     -H "X-API-Key: $TESTCASE_API_KEY" \
     -F "document_text=$DOC_CONTENT" \
     -F "document_name=<КОРОТКОЕ_ИМЯ>.md" \
     -F "mode=full" \
     --max-time 600
   ```
4. **Проверь результат** — убедись что `testcases` массив НЕ пустой
5. **Сохрани результат** в `workspace/qa-automation/test-cases/{project}/suite.json`
6. **Проверь test_data** — если тесты ссылаются на файлы, проверь их наличие в `test-data/{project}/`

## КРИТИЧНО: Правильная передача документа

**ПРАВИЛЬНО** (текст содержимого):
```bash
DOC_CONTENT=$(cat /opt/data/cache/documents/my_doc.md)
curl ... -F "document_text=$DOC_CONTENT" -F "document_name=my_doc.md" -F "mode=full"
```

**НЕПРАВИЛЬНО** (stdin redirect — ненадёжно, API может получить бинарный поток):
```bash
curl ... -F "document_text=<-" < /path/to/file.md        # ❌ НЕ ДЕЛАЙ ТАК
curl ... -F "document_text=@/path/to/file.md"             # ❌ отправит как file upload
curl ... -d '{"document_text": "..."}' -H "application/json"  # ❌ API не принимает JSON
```

## Обработка ошибок

Если API вернул `testcases: []` (пустой массив):
1. Проверь что document_text содержит реальный текст, а не путь к файлу
2. Проверь что document_name задан
3. Повтори запрос один раз
4. Если снова пусто — сообщи оркестратору об ошибке API, НЕ генерируй тесты сам

## Формат ответа
- `status`: ok | error | needs_input
- `coverage`: { total_testcases, by_priority }
- `artifacts`: путь к сохранённому JSON
- `missing_files`: список недостающих файлов тестовых данных

## Ограничения
- НЕ пиши тесты сам — только через API
- НЕ выполняй тесты
- Timeout API: минимум 600 секунд
- Всегда передавай document_name
- Для очень больших документов (>100KB): разбей на части и отправь несколько запросов
