#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# switch-model.sh – make <alias> the active model for vLLM
# -----------------------------------------------------------------------------
# Usage:
#   switch-model.sh <alias>
# -----------------------------------------------------------------------------
set -euo pipefail

ALIAS="${1:-}"
MODELS_DIR="/opt/shai/models"
TARGET_DIR="$MODELS_DIR/$ALIAS"
SYMLINK="/opt/shai/vllm/current_model"
BIN_LOG="/opt/shai/logs/bin-actions.log"

usage() {
  echo "Usage: $0 <alias>" >&2
  echo "Available aliases:" >&2
  ls -1 "$MODELS_DIR" >&2
  exit 1
}

ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

log_action() {
  echo "$(ts) [user:$USER] [action:switch-model] model='$ALIAS'" >> "$BIN_LOG"
}

[[ -z "$ALIAS" ]] && usage
[[ ! -d "$TARGET_DIR" ]] && { echo "❌ Model alias '$ALIAS' does not exist." >&2; exit 1; }

# Remove old symlink and create new one
rm -f "$SYMLINK"
ln -s "$TARGET_DIR" "$SYMLINK"

echo "🔁 Model switched to '$ALIAS'. Restarting vLLM container…"

docker compose --project-directory $(dirname $(realpath "$0"))/../compose restart vllm-server

log_action

echo "✅ vLLM is now serving model '$ALIAS'."