# claude-desktop-proxy

[English](README.md) · **Русский**

Запуск десктопного **Claude.app** (macOS) через персональный прокси — но только для трафика к Anthropic и только для самого приложения. Системные сетевые настройки не трогаются, всё остальное идёт напрямую.

Локальный [mihomo](https://github.com/MetaCubeX/mihomo) в режиме `rule` заворачивает `anthropic.com` / `claude.ai` / `claudeusercontent.com` на апстрим-прокси; всё прочее — `DIRECT`.

```
Claude.app ──► локальный mihomo (127.0.0.1:7890) ──► upstream proxy ──► Anthropic
                        │
                        └► всё остальное ──► DIRECT
```

## Требования

- macOS (Apple Silicon или Intel), `Claude.app` в `/Applications`.
- [Homebrew](https://brew.sh) + mihomo: `brew install mihomo`
- Апстрим HTTP-прокси с логином/паролем.

## Установка

```sh
git clone https://github.com/DenoBY/claude-desktop-proxy.git ~/.claude-proxy
cd ~/.claude-proxy

cp config.env.example config.env      # впиши сюда свой апстрим-прокси
chmod 600 config.env

./gen-mihomo-config.sh                 # пишет /opt/homebrew/etc/mihomo/config.yaml
./launch.sh                            # поднимает mihomo + Claude.app с прокси-флагами
```

`config.env` в `.gitignore` — креды не попадают в git.

## Ярлык в /Applications (опционально)

Оберни `launch.sh` в приложение, чтобы запускать из Spotlight/Launchpad:

1. **Script Editor** → новый документ:
   ```applescript
   do shell script "$HOME/.claude-proxy/launch.sh > /dev/null 2>&1 &"
   ```
2. **File → Export…** → File Format **Application**, имя `Claude Proxy`, сохрани в `/Applications`.
3. (Опц.) поставь иконку Claude. Выполни в Терминале — тут полные пути, просто скопируй:
   ```sh
   APP="/Applications/Claude Proxy.app"
   cp "/Applications/Claude.app/Contents/Resources/electron.icns" "$APP/Contents/Resources/applet.icns"
   # macOS берёт иконку из каталога ассетов, а не из .icns — удаляем его, чтобы использовался .icns
   rm -f "$APP/Contents/Resources/Assets.car"
   /usr/libexec/PlistBuddy -c 'Delete :CFBundleIconName' "$APP/Contents/Info.plist"
   codesign --force --deep --sign - "$APP"   # пересобрать подпись после правки бандла
   ```

## Файлы

| Файл | Назначение |
|------|------------|
| `config.env` | Секреты: `CLAUDE_UPSTREAM_PROXY` (в `.gitignore`). |
| `config.env.example` | Шаблон для `config.env`. |
| `gen-mihomo-config.sh` | Разбирает `CLAUDE_UPSTREAM_PROXY`, пишет `config.yaml` mihomo. |
| `launch.sh` | Поднимает mihomo и стартует Claude.app с `--proxy-server`. |

### Правила маршрутизации

```yaml
rules:
  - DOMAIN-SUFFIX,anthropic.com,CLAUDE
  - DOMAIN-SUFFIX,claude.ai,CLAUDE
  - DOMAIN-SUFFIX,claudeusercontent.com,CLAUDE
  - MATCH,DIRECT
```

Чтобы гнать через прокси больше доменов — добавь строки `DOMAIN-SUFFIX,...,CLAUDE` перед `MATCH,DIRECT` и перегенерируй конфиг.

## Заметки

- Порт локального прокси — `7890` (задан в `launch.sh` и генераторе).
- `launch.sh` учитывает single-instance lock Electron, установку обновления Squirrel при выходе и запуск arm64-среза вместо x86 под Rosetta.
