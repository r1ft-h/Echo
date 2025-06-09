#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# add-model.sh – download a Hugging Face model into /opt/shai/models/<alias>
# -----------------------------------------------------------------------------
# Usage:
#   add-model.sh <alias> <huggingface_repo_id> [--quant awq|gptq|none]
# Example:
#   add-model.sh mistral7b-awq mistralai/Mistral-7B-Instruct-v0.2-AWQ --quant awq
# -----------------------------------------------------------------------------
set -euo pipefail

ALIAS="${1:-}"
REPO="${2:-}"
QUANT_FLAG="${3:---quant none}"

MODELS_DIR="/opt/shai/models"
TARGET_DIR="$MODELS_DIR/$ALIAS"
BIN_LOG="/opt/shai/logs/bin-actions.log"
ENV_FILE="/opt/shai/.env"             # created by setup script

# ─────────────────────── Functions ───────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $0 <alias> <huggingface_repo_id> [--quant awq|gptq|none]
Example: $0 mistral7b-awq mistralai/Mistral-7B-Instruct-v0.2-AWQ --quant awq
EOF
  exit 1
}

ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

log_action() {
  echo "$(ts) [user:$USER] [action:add-model] alias='$ALIAS' repo='$REPO' quant='${QUANT_FLAG#--quant }'" >> "$BIN_LOG"
}

# ─────────────────────── Validation ──────────────────────────────────────────
[[ -z "$ALIAS" || -z "$REPO" ]] && usage
[[ -d "$TARGET_DIR" ]] && { echo "❌ Alias '$ALIAS' already exists in $MODELS_DIR" >&2; exit 1; }

# ─────────────────────── Download model ──────────────────────────────────────
mkdir -p "$TARGET_DIR"

echo "⬇️  Downloading model '$REPO' as alias '$ALIAS'…"
if command -v huggingface-cli &>/dev/null; then
  huggingface-cli download "$REPO" --local-dir "$TARGET_DIR" --local-dir-use-symlinks False
else
  echo "huggingface-cli not found – falling back to git clone" >&2
  git clone --depth 1 "https://huggingface.co/$REPO.git" "$TARGET_DIR"
fi

echo "✅ Model downloaded to $TARGET_DIR"

# ─────────────────────── Update .env quant flag ─────────────────────────────-
if [[ "$QUANT_FLAG" != "--quant none" ]]; then
  QUANT_VALUE="${QUANT_FLAG#--quant }"
  if [[ -f "$ENV_FILE" ]]; then
    sed -i "s/^MODEL_QUANT=.*/MODEL_QUANT=$QUANT_VALUE/" "$ENV_FILE"
  else
    echo "MODEL_QUANT=$QUANT_VALUE" >> "$ENV_FILE"
  fi
  echo "ℹ️  MODEL_QUANT updated to '$QUANT_VALUE' in $ENV_FILE."
fi

log_action

echo "Done. You can now activate the model with: switch-model.sh $ALIAS"