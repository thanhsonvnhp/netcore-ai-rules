#!/usr/bin/env bash
# One-command installer for netcore-ai-rules
# Usage:
#   ./install.sh [target-dir]                          # local (after clone)
#   ./install.sh ../CRM                      # copy to ../CRM
#   curl -fsSL https://raw.githubusercontent.com/thanhsonvnhp/netcore-ai-rules/main/install.sh | bash -s -- ../MyProject
#   # Placeholders: edit .ai-rules/TEMPLATE_VARS.md or pass via env before running
#   # See .ai-rules/TEMPLATE_VARS.md for examples (CRM vs AcmePlatform).
set -euo pipefail
SRC="$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo "")"
TARGET="${1:-.}"
FORCE="${FORCE:-0}"
if [ ! -d "$SRC/.ai-rules" ]; then
  echo "[netcore-ai-rules] .ai-rules not found next to script, cloning..."
  TMP="/tmp/netcore-ai-rules-$(date +%s)"
  git clone --depth 1 https://github.com/thanhsonvnhp/netcore-ai-rules.git "$TMP"
  SRC="$TMP"
fi
TARGET="$(cd "$TARGET" 2>/dev/null && pwd || mkdir -p "$TARGET" && cd "$TARGET" && pwd)"
echo "[netcore-ai-rules] Source: $SRC"
echo "[netcore-ai-rules] Target: $TARGET"
copy_tree() {
  local src="$SRC/$1" dst="$TARGET/$2"
  [ -d "$src" ] || { echo "  skip $1 (not in source)"; return 0; }
  mkdir -p "$dst"
  while IFS= read -r -d '' f; do
    rel="${f#$src/}"
    dest="$dst/$rel"
    if [ -f "$dest" ] && [ "$FORCE" != "1" ]; then echo "  skip $2/$rel (exists, FORCE=1 to overwrite)"; continue; fi
    mkdir -p "$(dirname "$dest")"
    cp -f "$f" "$dest"
    echo "  + $2/$rel"
  done < <(find "$src" -type f -print0)
}
copy_file() {
  local src="$SRC/$1" dst="$TARGET/$2"
  [ -f "$src" ] || return 0
  if [ -f "$dst" ] && [ "$FORCE" != "1" ]; then echo "  skip $2 (exists)"; return 0; fi
  mkdir -p "$(dirname "$dst")"
  cp -f "$src" "$dst"
  echo "  + $2"
}
echo "[1/3] .ai-rules/ ..."
copy_tree ".ai-rules" ".ai-rules"
echo "[2/3] skills ..."
copy_tree ".agents/skills" ".agents/skills"
echo "[3/3] entry docs ..."
copy_file "CLAUDE.md" "CLAUDE.md"
copy_file "AGENTS.md" "AGENTS.md"
if grep -q "{ProjectName}\|{Company}\|{database}" "$TARGET/.ai-rules/core/01-project-hard-rules.md" 2>/dev/null; then
  echo ""
  echo "[netcore-ai-rules] Done. Placeholders still present — run with replacements:"
  echo "  FORCE=1 ./install.sh .   # after editing .ai-rules/TEMPLATE_VARS.md"
  echo "  # or edit .ai-rules/core/01-project-hard-rules.md directly"
else
  echo "[netcore-ai-rules] Done."
fi
