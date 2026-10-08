# Тест-раннеры по стекам

Выбирай по стеку из `SPEC.md`. Команду прогона запиши в `CLAUDE.md` проекта и в `SPEC.md` → «Как проверить».

## python (по умолчанию для ботов и утилит)
На Маке есть `uv`, глобального `pytest` нет — ставь в проект.
```bash
cd <проект>
uv init --package --no-workspace --name <имя> .   # src/<пакет>/ + [project.scripts] сразу
uv add --dev pytest
uv run pytest -q
```
- Структура: `src/<пакет>/…` (uv делает сам), тесты в `tests/`. CLI-команда из `[project.scripts]` запускается `uv run <имя>`.
- Чтобы `tests/` видел пакет: в `pyproject.toml`
  ```toml
  [tool.pytest.ini_options]
  pythonpath = ["."]
  testpaths = ["tests"]
  ```
- Async (aiogram, httpx): `uv add --dev pytest-asyncio`, в конфиге `asyncio_mode = "auto"`.
- HTTP-моки: `uv add --dev respx` (httpx) или `responses` (requests).
- CLI: тестируй через `subprocess.run([sys.executable, "-m", "<пакет>", …])` или `main(argv)` с `capsys`; проверяй stdout, stderr и код выхода.

## node / TypeScript
```bash
cd <проект>
npm init -y
npm i -D vitest
npm pkg set scripts.test="vitest run"
npm test
```
- ESM: `npm pkg set type=module`.
- TypeScript: `npm i -D typescript` — vitest понимает `.ts` сам.
- DOM-код: `npm i -D jsdom`, в начале теста `// @vitest-environment jsdom`.

## web (статичный сайт / ванильный JS)
Логику выноси в модули без DOM и тестируй vitest-ом (как node). Вёрстку и поведение страницы проверяй вручную во встроенном браузере (preview) — пометь такие требования `(ручная проверка)` в SPEC.md. Для дизайна сайта дополнительно скилл `/web-design`.

## swift (macOS-приложения)
Swift Package:
```bash
swift package init --type executable   # или --type library
swift test
```
Логику держи в library-таргете, чтобы её можно было тестировать без UI. Проекты владельца собираются `./build.sh install` — добавь `build.sh`, если нужен .app.

## other
Подбери стандартный раннер языка (go test, cargo test, bats для shell). Если автотесты невозможны в принципе, скажи владельцу до этапа 3 и договорись о ручных критериях в SPEC.md.
