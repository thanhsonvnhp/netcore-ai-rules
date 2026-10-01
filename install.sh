#!/usr/bin/env bash
# One-command installer for netcore-ai-rules
# Usage:
#   ./install.sh [target-dir]                          # local (after clone)
#   ./install.sh ../CRM                                # copy to ../CRM
#   curl -fsSL https://raw.githubusercontent.com/thanhsonvnhp/netcore-ai-rules/main/install.sh | bash -s -- ../MyProject
#
# Placeholder replacement (optional env vars, same as install.ps1 parameters):
#   COMPANY=Acme PROJECT_NAME=AcmePlatform DATABASE=acme_db SCHEMA=catalog NAMESPACE=acme ./install.sh ../AcmePlatform
#   FORCE=1 overwrites existing files (use it to re-apply placeholders to an existing install).
# See .ai-rules/TEMPLATE_VARS.md for what each placeholder means.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo "")"
TARGET="${1:-.}"
FORCE="${FORCE:-0}"
COMPANY="${COMPANY:-}"
PROJECT_NAME="${PROJECT_NAME:-}"
DATABASE="${DATABASE:-}"
SCHEMA="${SCHEMA:-}"
NAMESPACE="${NAMESPACE:-}"
if [ ! -d "$SRC/.ai-rules" ]; then
  echo "[netcore-ai-rules] .ai-rules not found next to script, cloning..."
  TMP="/tmp/netcore-ai-rules-$(date +%s)"
  git clone --depth 1 https://github.com/thanhsonvnhp/netcore-ai-rules.git "$TMP"
  SRC="$TMP"
fi
if [ ! -d "$TARGET" ]; then mkdir -p "$TARGET"; fi
TARGET="$(cd "$TARGET" && pwd)"
echo "[netcore-ai-rules] Source: $SRC"
echo "[netcore-ai-rules] Target: $TARGET"

# Escape a value for use as a sed replacement with '|' as the delimiter
sed_escape() { printf '%s' "$1" | sed -e 's/[\\|&]/\\&/g'; }

# Replace global {Placeholder} values in one file. <placeholder> forms are never touched.
# TEMPLATE_VARS.md is skipped: it documents the placeholder names, replacing them would destroy its own table.
replace_placeholders() {
  local file="$1"
  local -a args=()
  [ "$(basename "$file")" = "TEMPLATE_VARS.md" ] && return 0
  # Build sed arguments as an array so values containing spaces stay one argument
  [ -n "$COMPANY" ]      && args+=(-e "s|{Company}|$(sed_escape "$COMPANY")|g")
  [ -n "$PROJECT_NAME" ] && args+=(-e "s|{ProjectName}|$(sed_escape "$PROJECT_NAME")|g")
  [ -n "$DATABASE" ]     && args+=(-e "s|{database}|$(sed_escape "$DATABASE")|g")
  [ -n "$SCHEMA" ]       && args+=(-e "s|{schema}|$(sed_escape "$SCHEMA")|g")
  [ -n "$NAMESPACE" ]    && args+=(-e "s|{namespace}|$(sed_escape "$NAMESPACE")|g")
  [ "${#args[@]}" -gt 0 ] || return 0
  # Write to a temp file then move: portable across GNU and BSD/macOS sed (no -i).
  # On failure remove the temp file so no half-written file is left behind.
  if sed "${args[@]}" "$file" > "$file.tmp"; then
    mv "$file.tmp" "$file"
  else
    rm -f "$file.tmp"
    echo "  ERROR: placeholder replacement failed for $file" >&2
    return 1
  fi
}

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
    replace_placeholders "$dest"
    echo "  + $2/$rel"
  done < <(find "$src" -type f -print0)
}
copy_file() {
  local src="$SRC/$1" dst="$TARGET/$2"
  [ -f "$src" ] || return 0
  if [ -f "$dst" ] && [ "$FORCE" != "1" ]; then echo "  skip $2 (exists)"; return 0; fi
  mkdir -p "$(dirname "$dst")"
  cp -f "$src" "$dst"
  replace_placeholders "$dst"
  echo "  + $2"
}
echo "[1/3] .ai-rules/ ..."
copy_tree ".ai-rules" ".ai-rules"
echo "[2/3] skills ..."
# Install to .agents/skills (generic) + .claude/skills (Claude Code discovers skills here)
copy_tree ".agents/skills" ".agents/skills"
copy_tree ".agents/skills" ".claude/skills"
echo "[3/3] entry docs ..."
copy_file "CLAUDE.md" "CLAUDE.md"
copy_file "AGENTS.md" "AGENTS.md"
# Personal plan folder - its .gitignore keeps every plan file out of git
copy_file ".plans/.gitignore" ".plans/.gitignore"
if grep -q "{ProjectName}\|{Company}\|{database}" "$TARGET/.ai-rules/core/01-project-hard-rules.md" 2>/dev/null; then
  echo ""
  echo "[netcore-ai-rules] Done. Placeholders still present - re-run with values:"
  echo "  COMPANY=Acme PROJECT_NAME=MyApp DATABASE=myapp SCHEMA=app FORCE=1 ./install.sh ."
  echo "  # See .ai-rules/TEMPLATE_VARS.md"
else
  echo "[netcore-ai-rules] Done."
fi
