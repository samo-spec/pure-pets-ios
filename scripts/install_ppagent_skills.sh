#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
DEST="$ROOT/.agents/vendor"

resolve_ppagent_root() {
  local candidates=()
  if [[ -n "${PPAGENT_ROOT:-}" ]]; then
    candidates+=("$PPAGENT_ROOT")
  fi
  candidates+=("$ROOT/../PPAgents" "$ROOT/../PPAgent")

  local p
  for p in "${candidates[@]}"; do
    if [[ -d "$p" ]]; then
      (cd "$p" && pwd)
      return 0
    fi
  done
  return 1
}

PPROOT="$(resolve_ppagent_root || true)"
if [[ -z "$PPROOT" ]]; then
  echo "ERROR: PPAgent checkout not found. Set PPAGENT_ROOT or place PPAgents/PPAgent beside pure-pets-ios." >&2
  exit 1
fi

mkdir -p "$DEST"

echo "PPAgent source: $PPROOT"

echo "Installing Pure Pets Firebase Mission Control V3..."
MC_SRC="$PPROOT/pure-pets-firebase-mission-control-v3/skills/pure-pets-firebase-mission-control-v3"
if [[ ! -f "$MC_SRC/SKILL.md" ]]; then
  echo "ERROR: Mission Control V3 SKILL.md not found at: $MC_SRC" >&2
  exit 1
fi
rm -rf "$DEST/pure-pets-firebase-mission-control-v3"
mkdir -p "$DEST/pure-pets-firebase-mission-control-v3"
rsync -a --delete \
  --exclude '.DS_Store' \
  --exclude '__pycache__' \
  --exclude '*.pyc' \
  "$MC_SRC/" "$DEST/pure-pets-firebase-mission-control-v3/"

echo "Installing SwiftyMax NextGen Category-Defining V6..."
SWIFTY_DIR="$PPROOT/swiftymax-nextgen-category-defining-v6"
SWIFTY_ZIP="$PPROOT/swiftymax-nextgen-category-defining-v6.zip"
SWIFTY_DEST="$DEST/swiftymax-nextgen-category-defining-v6"
rm -rf "$SWIFTY_DEST"
mkdir -p "$SWIFTY_DEST"

if [[ -f "$SWIFTY_DIR/SKILL.md" ]]; then
  rsync -a --delete \
    --exclude '.git' \
    --exclude '.DS_Store' \
    --exclude '__MACOSX' \
    "$SWIFTY_DIR/" "$SWIFTY_DEST/"
elif [[ -f "$SWIFTY_ZIP" ]]; then
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  unzip -q -o "$SWIFTY_ZIP" -d "$TMP"
  SKILL_FILE="$(find "$TMP" -type f -name SKILL.md -path '*swiftymax-nextgen-category-defining-v6*' -print -quit)"
  if [[ -z "$SKILL_FILE" ]]; then
    SKILL_FILE="$(find "$TMP" -type f -name SKILL.md -print -quit)"
  fi
  if [[ -z "$SKILL_FILE" ]]; then
    echo "ERROR: V6 ZIP extracted, but no SKILL.md was found." >&2
    exit 1
  fi
  V6_SRC="$(dirname "$SKILL_FILE")"
  rsync -a --delete \
    --exclude '.git' \
    --exclude '.DS_Store' \
    --exclude '__MACOSX' \
    "$V6_SRC/" "$SWIFTY_DEST/"
else
  echo "ERROR: SwiftyMax V6 source directory/ZIP not found in $PPROOT" >&2
  exit 1
fi

for required in \
  "$DEST/pure-pets-firebase-mission-control-v3/SKILL.md" \
  "$DEST/swiftymax-nextgen-category-defining-v6/SKILL.md"; do
  if [[ ! -s "$required" ]]; then
    echo "ERROR: installation incomplete: $required" >&2
    exit 1
  fi
done

echo "Installed project-local PPAgent skills:"
echo "  $DEST/pure-pets-firebase-mission-control-v3"
echo "  $DEST/swiftymax-nextgen-category-defining-v6"
echo "Restart/reload Codex if skill discovery does not refresh automatically."
