#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# add-model.sh – download a Hugging Face model into /opt/echo/models/<alias>
# -----------------------------------------------------------------------------
# Usage:
#   add-model.sh <alias> <hf_repo_id> [--quant awq|gptq|none]
# -----------------------------------------------------------------------------
set -euo pipefail

# API token explicitly set here
HF_TOKEN="XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

ALIAS="${1:-}"
REPO="${2:-}"
QUANT_FLAG="${3:---quant none}"

MODELS_DIR="/opt/echo/models"
TARGET_DIR="$MODELS_DIR/$ALIAS"
BIN_LOG="/opt/echo/logs/bin-actions.log"
ENV_FILE="/opt/echo/.env"

usage() {
  cat <<EOF
Usage: $0 <alias> <hf_repo_id> [--quant awq|gptq|none]
Example: $0 mistral7b-awq mistralai/Mistral-7B-Instruct-v0.2-AWQ --quant awq
EOF
  exit 1
}

ts()   { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log()  { echo "$(ts) [user:$USER] [action:add-model] $1" >> "$BIN_LOG"; }

[[ -z "$ALIAS" || -z "$REPO" ]] && usage

# Ensure required directories exist
mkdir -p /opt/echo/{models,vllm,logs,bin,openwebui/data}
[ -f "$ENV_FILE" ] || touch "$ENV_FILE"

if [[ -d "$TARGET_DIR" ]]; then
  echo "⚠️  Alias '$ALIAS' already exists. Cleaning up…"
  rm -rf "$TARGET_DIR"
fi

mkdir -p "$TARGET_DIR"
echo "⬇️  Downloading model '$REPO' as alias '$ALIAS'…"

if command -v huggingface-cli &>/dev/null; then
  huggingface-cli download "$REPO" --local-dir "$TARGET_DIR" --local-dir-use-symlinks False --token "$HF_TOKEN"
else
  GIT_ASKPASS="/bin/echo" git clone --depth 1 \
    "https://oauth2:${HF_TOKEN}@huggingface.co/${REPO}.git" "$TARGET_DIR"
fi

echo "✅ Model saved to $TARGET_DIR"

# Update MODEL_QUANT in .env if requested
if [[ "$QUANT_FLAG" != "--quant none" ]]; then
  VALUE="${QUANT_FLAG#--quant }"
  if grep -q '^MODEL_QUANT=' "$ENV_FILE" 2>/dev/null; then
    sed -i "s/^MODEL_QUANT=.*/MODEL_QUANT=$VALUE/" "$ENV_FILE"
  else
    echo "MODEL_QUANT=$VALUE" >> "$ENV_FILE"
  fi
  echo "ℹ️  MODEL_QUANT set to '$VALUE' in .env"
fi

log "alias='$ALIAS' repo='$REPO' quant='${QUANT_FLAG#--quant }'"
echo "Done. Activate with: switch-model.sh $ALIAS"
