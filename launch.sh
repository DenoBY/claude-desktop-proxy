#!/bin/bash
# Запускает Claude.app через локальный mihomo (конфиг — gen-mihomo-config.sh).
# Прокси только для этого приложения: системные настройки сети не трогаем.
set -uo pipefail

BASE="$HOME/.claude-proxy"
CLAUDE_BIN="/Applications/Claude.app/Contents/MacOS/Claude"
PORT=7890

[ -x "$CLAUDE_BIN" ] || {
  osascript -e 'display alert "Claude не найден" message "Ожидался /Applications/Claude.app"'
  exit 1
}

MIHOMO="/opt/homebrew/opt/mihomo/bin/mihomo"
MIHOMO_DIR="/opt/homebrew/etc/mihomo"

# Запускаем mihomo напрямую (не через brew services), чтобы не прописывать его
# в «Элементы входа»: автозапуск при логине пользователю не нужен.
if ! nc -z 127.0.0.1 "$PORT" 2>/dev/null; then
  nohup "$MIHOMO" -d "$MIHOMO_DIR" >>"$BASE/mihomo.log" 2>&1 &
  for _ in $(seq 1 50); do
    nc -z 127.0.0.1 "$PORT" 2>/dev/null && break
    sleep 0.1
  done
fi

nc -z 127.0.0.1 "$PORT" 2>/dev/null || {
  osascript -e "display alert \"mihomo не поднялся\" message \"Порт $PORT молчит. Лог: $BASE/mihomo.log\""
  exit 1
}

# Electron держит single-instance lock: без этого повторный запуск просто
# активирует уже открытое окно, и флаги прокси будут проигнорированы.
osascript -e 'quit app "Claude"' >/dev/null 2>&1
for _ in $(seq 1 50); do
  pgrep -x Claude >/dev/null 2>&1 || break
  sleep 0.2
done
pgrep -x Claude >/dev/null 2>&1 && { pkill -x Claude; sleep 1; }

# Squirrel ставит скачанное обновление в момент выхода приложения. Если стартовать
# сейчас, мы поймаем бандл в процессе подмены и запустимся в пустоту.
for _ in $(seq 1 120); do
  pgrep -f 'ShipIt com.anthropic.claudefordesktop' >/dev/null 2>&1 || break
  sleep 0.5
done

[ -x "$CLAUDE_BIN" ] || {
  osascript -e 'display alert "Claude не найден после обновления" message "Бандл /Applications/Claude.app повреждён или переехал."'
  exit 1
}


PROXY="http://127.0.0.1:$PORT"
export HTTP_PROXY="$PROXY" HTTPS_PROXY="$PROXY" ALL_PROXY="$PROXY"
export http_proxy="$PROXY" https_proxy="$PROXY" all_proxy="$PROXY"
export NO_PROXY="localhost,127.0.0.1,::1" no_proxy="localhost,127.0.0.1,::1"

# Universal-бандл иначе может запуститься x86-срезом под Rosetta и утащить туда же
# claude-code — сжигает CPU и вешает интерфейс. Смотрим на железо, а не на uname:
# под Rosetta uname -m врёт и отвечает x86_64.
if [ "$(sysctl -n hw.optional.arm64 2>/dev/null)" = "1" ]; then
  nohup arch -arm64 "$CLAUDE_BIN" \
    --proxy-server="$PROXY" \
    --proxy-bypass-list="<local>" \
    >>"$BASE/claude.log" 2>&1 &
else
  nohup "$CLAUDE_BIN" \
    --proxy-server="$PROXY" \
    --proxy-bypass-list="<local>" \
    >>"$BASE/claude.log" 2>&1 &
fi
disown
exit 0
