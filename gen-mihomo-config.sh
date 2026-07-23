#!/bin/bash
# Генерирует конфиг mihomo из CLAUDE_UPSTREAM_PROXY (см. config.env).
# Креды живут только в config.env и в готовом конфиге (оба chmod 600).
set -euo pipefail

BASE="$HOME/.claude-proxy"
OUT="/opt/homebrew/etc/mihomo/config.yaml"

set -a
# shellcheck disable=SC1091
. "$BASE/config.env"
set +a

: "${CLAUDE_UPSTREAM_PROXY:?не задан в config.env}"

# Разбираем http://user:pass@host:port, percent-decoding в user/pass.
read -r UP_HOST UP_PORT UP_USER UP_PASS <<EOF
$(/usr/bin/python3 - "$CLAUDE_UPSTREAM_PROXY" <<'PY'
import sys, urllib.parse as u
p = u.urlparse(sys.argv[1])
print(p.hostname, p.port or 3128,
      u.unquote(p.username or ""), u.unquote(p.password or ""))
PY
)
EOF

mkdir -p "$(dirname "$OUT")"
umask 077

cat >"$OUT" <<YAML
# Сгенерировано gen-mihomo-config.sh — правки затрёт следующий запуск.
mixed-port: 7890
mode: rule
log-level: warning
ipv6: false
allow-lan: false
unified-delay: true
tcp-concurrent: true
external-controller: 127.0.0.1:9090

proxies:
  - name: upstream
    type: http
    server: $UP_HOST
    port: $UP_PORT
    username: "$UP_USER"
    password: "$UP_PASS"

proxy-groups:
  - name: CLAUDE
    type: select
    proxies: [upstream, DIRECT]

# Через прокси — только Claude. Остальное (обновления, телеметрия, весь прочий
# трафик системы) идёт напрямую и не платит за круг через Германию.
rules:
  - DOMAIN-SUFFIX,anthropic.com,CLAUDE
  - DOMAIN-SUFFIX,claude.ai,CLAUDE
  - DOMAIN-SUFFIX,claudeusercontent.com,CLAUDE
  - MATCH,DIRECT
YAML

chmod 600 "$OUT"
echo "конфиг записан: $OUT (upstream $UP_HOST:$UP_PORT)"
