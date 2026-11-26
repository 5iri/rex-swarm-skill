#!/bin/sh
# Installs swarm on macOS/Linux. Re-run to update. Nothing outside these paths is touched.
#   ~/.local/bin/swarm                      CLI
#   ~/.config/rex/swarm.lua                 Rex actions + key bindings (require("swarm"))
#   ~/.config/rex/swarm-watch.lua           Rex event forwarder (started by `swarm up`)
#   ~/.claude/skills/swarm-{lead,worker}    Claude Code skills
#   ~/.codex/skills/swarm-{lead,worker}     Codex skills (if ~/.codex exists)
#   ~/.agents/skills/swarm-{lead,worker}    agy / Antigravity skills (if ~/.agents exists)
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
REX_CFG="${REX_CONFIG_DIR:-$HOME/.config/rex}"

mkdir -p "$HOME/.local/bin" "$REX_CFG"
install -m 755 "$HERE/bin/swarm" "$HOME/.local/bin/swarm"
install -m 644 "$HERE/rex/swarm.lua" "$REX_CFG/swarm.lua"
install -m 644 "$HERE/rex/swarm-watch.lua" "$REX_CFG/swarm-watch.lua"

if [ -f "$REX_CFG/init.lua" ]; then
  grep -q 'require("swarm")' "$REX_CFG/init.lua" || printf '\nrequire("swarm")\n' >> "$REX_CFG/init.lua"
else
  printf 'require("swarm")\n' > "$REX_CFG/init.lua"
fi

for d in "$HOME/.claude/skills" "$HOME/.codex/skills" "$HOME/.agents/skills"; do
  parent=$(dirname "$d")
  [ -d "$parent" ] || continue
  mkdir -p "$d"
  for s in swarm-lead swarm-worker; do
    mkdir -p "$d/$s" && cp "$HERE/skills/$s/SKILL.md" "$d/$s/SKILL.md"
  done
  echo "skills -> $d"
done

case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) echo "add ~/.local/bin to PATH";; esac
echo "installed. Reload Rex config, then check: rex api describe session.new_window"
