<img width="506" height="265" alt="image" src="https://github.com/user-attachments/assets/a6ddf52d-f69d-4fb1-9a9c-667055f7fef5" /># Free Claude Code — Antigravity Manager setup

Форк [Alishahryar1/free-claude-code](https://github.com/Alishahryar1/free-claude-code) с патчами для работы через **Antigravity-Manager** и скриптом переключения моделей.

Общая документация, установка uv, архитектура и список провайдеров — в [оригинальном README](https://github.com/Alishahryar1/free-claude-code).

---

## Что добавлено / изменено

### Патчи под Antigravity-Manager

Antigravity-Manager принимает **OpenAI Chat Completions**, а не Anthropic Messages. Пять изменений:

| Файл | Изменение |
|------|-----------|
| `providers/lmstudio/client.py` | `AnthropicMessagesTransport` → `OpenAIChatTransport` |
| `providers/lmstudio/request.py` | **[NEW]** билдер запросов + `_normalize_system_messages()` |
| `config/provider_catalog.py` | `transport_type` → `"openai_chat"`, API-ключ Antigravity |
| `api/models/anthropic.py` | роль `"system"` добавлена в `Message.role` (Claude Code v2.1+ шлёт её в массиве messages) |
| `.env` | `ANTHROPIC_AUTH_TOKEN=` (пусто), модели → `claude-sonnet-4-6` / `claude-opus-4-6` / `claude-haiku-4` |

**Зачем `_normalize_system_messages`:** Antigravity не принимает `role: "system"` в середине массива messages. Функция объединяет все system-блоки с первым user-сообщением.

### `model-switch.ps1` — интерактивная переключалка моделей

Консольное меню (стрелки ↑↓ + Enter): выбирает модель, пишет её в `~/.claude/settings.json` и автоматически переключает VS Code в нужный режим.

```powershell
.\model-switch.ps1
```
<img width="506" height="265" alt="image" src="https://github.com/user-attachments/assets/1be2e09b-8da4-4621-a06a-6766914917be" />

Список моделей редактируется в начале файла (массив `$Models`).

---

## Минимальная настройка `.env`

```env
LM_STUDIO_BASE_URL=http://127.0.0.1:8045/v1

MODEL_OPUS=lmstudio/claude-opus-4-6
MODEL_SONNET=lmstudio/claude-sonnet-4-6
MODEL_HAIKU=lmstudio/claude-haiku-4
MODEL=lmstudio/claude-sonnet-4-6

ANTHROPIC_AUTH_TOKEN=
FCC_OPEN_BROWSER=false
MESSAGING_PLATFORM=none
```

> Если что-то менялось через Admin UI — проверьте `~/.fcc/.env`: он загружается **после** основного `.env` и перезаписывает его.

## Запуск

```powershell
cd Free-claude-code-antigravity-tools
$env:NO_PROXY = "127.0.0.1,localhost"
$env:HTTP_PROXY = ""; $env:HTTPS_PROXY = ""; $env:ALL_PROXY = ""
uv run fcc-server
```

> Очистка прокси-переменных обязательна при использовании FixNet / Happ (SOCKS `127.0.0.1:10808`) — httpx подхватывает их и падает с `ValueError: Unknown scheme`.

---

## Настройки VS Code

Два режима в `%APPDATA%\Code\User\settings.json`:

**Режим 1 — Free (Antigravity):**
```json
{
    "http.proxySupport": "off",
    "claudeCode.environmentVariables": [
        { "name": "ANTHROPIC_BASE_URL", "value": "http://127.0.0.1:8082" },
        { "name": "ANTHROPIC_API_KEY", "value": "freecc" },
        { "name": "CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY", "value": "1" },
        { "name": "CLAUDE_CODE_AUTO_COMPACT_WINDOW", "value": "190000" },
        { "name": "NO_PROXY", "value": "127.0.0.1,localhost" },
        { "name": "HTTP_PROXY", "value": "" },
        { "name": "HTTPS_PROXY", "value": "" },
        { "name": "ALL_PROXY", "value": "" }
    ]
}
```

**Режим 2 — Sub (прямая подписка Anthropic):**
```json
{
    "http.proxySupport": "override",
    "claudeCode.environmentVariables": []
}
```

`http.proxySupport: "off"` в Режиме 1 обязателен — иначе VS Code инжектирует SOCKS в subprocess Claude Code, и запросы к `localhost:8082` уходят через VPN.

После смены режима: **File → Exit** и открыть VS Code заново (или `Ctrl+Shift+P` → `Developer: Reload Window`).

---

## Известные проблемы

**"All accounts failed or unhealthy"** — у Antigravity кончились аккаунты для модели. Переключитесь на другую модель через `model-switch.ps1`.

**Модели не появляются в пикере** — Claude Code откатывается на встроенные, если Antigravity возвращает 503/400. Проверьте: `curl http://127.0.0.1:8045/v1/chat/completions`.

**Gemini 400 (safety_settings / location)** — ограничения Google API, попробуйте другую Gemini-модель.
