# claude-desktop-proxy

**English** · [Русский](README.ru.md)

Launch the desktop **Claude.app** (macOS) through a personal proxy — but only for Anthropic traffic and only for the app itself. System network settings stay untouched; everything else goes direct.

A local [mihomo](https://github.com/MetaCubeX/mihomo) instance in `rule` mode routes `anthropic.com` / `claude.ai` / `claudeusercontent.com` to the upstream proxy; everything else stays `DIRECT`.

```
Claude.app ──► local mihomo (127.0.0.1:7890) ──► upstream proxy ──► Anthropic
                       │
                       └► everything else ──► DIRECT
```

## Requirements

- macOS (Apple Silicon or Intel) with `Claude.app` in `/Applications`.
- [Homebrew](https://brew.sh) + mihomo: `brew install mihomo`
- An upstream HTTP proxy with username/password.

## Setup

```sh
git clone https://github.com/DenoBY/claude-desktop-proxy.git ~/.claude-proxy
cd ~/.claude-proxy

cp config.env.example config.env      # put your upstream proxy here
chmod 600 config.env

./gen-mihomo-config.sh                 # writes /opt/homebrew/etc/mihomo/config.yaml
./launch.sh                            # starts mihomo + Claude.app with proxy flags
```

`config.env` is gitignored, so credentials never reach git.

## Launcher in /Applications (optional)

Wrap `launch.sh` in an app so it shows up in Spotlight/Launchpad:

1. **Script Editor** → new document:
   ```applescript
   do shell script "$HOME/.claude-proxy/launch.sh > /dev/null 2>&1 &"
   ```
2. **File → Export…** → File Format **Application**, name `Claude Proxy`, save to `/Applications`.
3. (Optional) give it Claude's icon. Run this in Terminal — full paths, just copy-paste:
   ```sh
   APP="/Applications/Claude Proxy.app"
   cp "/Applications/Claude.app/Contents/Resources/electron.icns" "$APP/Contents/Resources/applet.icns"
   # macOS prefers the asset catalog over the .icns — remove it so the .icns is used
   rm -f "$APP/Contents/Resources/Assets.car"
   /usr/libexec/PlistBuddy -c 'Delete :CFBundleIconName' "$APP/Contents/Info.plist"
   codesign --force --deep --sign - "$APP"   # re-sign after editing the bundle
   ```

## Files

| File | Purpose |
|------|---------|
| `config.env` | Secrets: `CLAUDE_UPSTREAM_PROXY` (gitignored). |
| `config.env.example` | Template for `config.env`. |
| `gen-mihomo-config.sh` | Parses `CLAUDE_UPSTREAM_PROXY`, writes mihomo's `config.yaml`. |
| `launch.sh` | Starts mihomo and launches Claude.app with `--proxy-server`. |

### Routing rules

```yaml
rules:
  - DOMAIN-SUFFIX,anthropic.com,CLAUDE
  - DOMAIN-SUFFIX,claude.ai,CLAUDE
  - DOMAIN-SUFFIX,claudeusercontent.com,CLAUDE
  - MATCH,DIRECT
```

Add more `DOMAIN-SUFFIX,...,CLAUDE` lines before `MATCH,DIRECT` and regenerate to route extra domains.

## Notes

- Local proxy port is `7890` (set in `launch.sh` and the generator).
- `launch.sh` handles Electron's single-instance lock, the Squirrel update installed on quit, and forces the arm64 slice instead of x86 under Rosetta.
