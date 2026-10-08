# silent-ugc (форк под kie.ai)

Скилл Claude Code: клонирует вирусные TikTok-хуки рекламы приложений со своим AI-актёром.

Основа — [jasonlee-breadcrumb/silent-ugc](https://github.com/jasonlee-breadcrumb/silent-ugc) (MIT, © 2026 Jason Lee), коммит `b9278da` от 20.08.2026. Оригинальные файлы — в `upstream/`.

## Что изменено
- Arcads MCP заменён на **kie.ai** через CLI `velsvisual` (скилл `visual`): nano-banana-2 (сцена с актёром), gpt-image-2 image-to-image (замена лица), Seedance 2.5 (перенос движения), запасной Kling 3.0 motion-control.
- Текст на видео, обрезка и склейка — локально ffmpeg: `scripts/cut.sh`, `scripts/add_text.sh`, `scripts/stitch.sh`, `scripts/scenes.sh`.
- `scripts/check_env.sh` — проверка ffmpeg/yt-dlp/ключа KIE и баланса.
- Смета перед запуском по живому прайсу kie.ai и правилам подтверждения из скилла `visual`.
- Инструкции на русском, промпты моделям на английском.

## Требования
- `velsvisual` (через `npx -y velsvisual`) с ключом KIE.
- ffmpeg с drawtext и yt-dlp. Без brew: `uv tool install yt-dlp`, `uv tool install static-ffmpeg && static_ffmpeg_paths`, затем симлинки ffmpeg/ffprobe в `~/.local/bin`.

## Тесты
```bash
bash tests/test_scripts.sh
```
