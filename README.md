# Claude Code skills

Скиллы для [Claude Code](https://claude.com/claude-code), которые я написал для себя.

| Скилл | Что делает |
|---|---|
| [web-design](web-design/) | Дизайн и вёрстка сайтов: вдохновение → `DESIGN.md` → сборка → проверка. Палитры, шрифты с кириллицей, анимации, шейдеры, шаблоны. Вызов `/web-design`. |
| [workflow-contract](workflow-contract/) | Старт нового проекта по регламенту: интервью → `SPEC.md` как контракт → красные тесты → реализация до зелёных → отчёт. |
| [audio-transcribe](audio-transcribe/) | Распознавание аудио (лекции, встречи, голосовые) офлайн на Apple Silicon с обязательной вычиткой. |
| [silent-ugc](silent-ugc/) | Форк [jasonlee-breadcrumb/silent-ugc](https://github.com/jasonlee-breadcrumb/silent-ugc) (MIT): клон TikTok-хуков с AI-актёром, генерация через kie.ai, склейка через ffmpeg. |

## Установка

Скопируйте папку нужного скилла в `~/.claude/skills/`:

```bash
git clone https://github.com/sunchaser15/claude-skills.git
cp -r claude-skills/web-design ~/.claude/skills/
```

Некоторые скиллы заточены под мою среду (пути, аккаунт GitHub) — поправьте под себя.
