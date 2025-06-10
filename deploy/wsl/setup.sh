#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# SHAI Stack – WSL 2 bootstrap script
# -----------------------------------------------------------------------------
# Target : Ubuntu 22.04 LTS inside WSL 2 (Windows 10/11)
# * Installs Docker CE + NVIDIA Container Toolkit
# * Creates /opt/shai directory tree, log infrastructure, logrotate rule
# * No UFW (handled by Windows Firewall)
# * English-only, non-interactive
# -----------------------------------------------------------------------------
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# ───────────────────────── Variables ─────────────────────────────────────────
SHAI_ROOT="/opt/shai"
LOG_DIR="$SHAI_ROOT/logs"
SETUP_LOG="$LOG_DIR/setup.log"

# ─────────────────── Ensure root privileges ──────────────────────────────────
if [[ "$EUID" -ne 0 ]]; then
  echo "🛑  Please run this script with sudo or as root." >&2
  exit 1
fi

CALLING_USER="$(logname)"

# ─────────────────── System update & base packages ───────────────────────────
echo "=== System update ==="
apt-get update -y
apt-get full-upgrade -y

apt-get install -y \
  curl ca-certificates gnupg lsb-release \
  git htop unzip tmux logrotate

# ───────────────────── Docker CE install ─────────────────────────────────────
if ! command -v docker &>/dev/null; then
  echo "=== Installing Docker CE ==="
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
     https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io \
                     docker-buildx-plugin docker-compose-plugin
fi

# ───── NVIDIA Container Toolkit (generic deb repository) ─────────────────────
if ! command -v nvidia-ctk &>/dev/null; then
  echo "=== Installing NVIDIA Container Toolkit ==="

  # GPG key
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
    | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

  # Generic repository (stable, deb)
  curl -sSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#' \
    > /etc/apt/sources.list.d/nvidia-container-toolkit.list

  apt-get update -y
  apt-get install -y nvidia-container-toolkit

  # Configure runtime
  nvidia-ctk runtime configure --runtime=docker
fi

# Restart Docker to activate NVIDIA runtime
systemctl restart docker

# ────────── Add invoking user to docker group ────────────────────────────────
if ! id -nG "$CALLING_USER" | grep -qw docker; then
  usermod -aG docker "$CALLING_USER"
  USER_NEEDS_RELOGIN=true
fi

# ────────────────── Create SHAI directory structure ──────────────────────────
mkdir -p "$SHAI_ROOT"/{bin,models,vllm,openwebui/data,logs}
chown -R "$CALLING_USER:$CALLING_USER" "$SHAI_ROOT"

# ──────────────── Initialize logrotate configuration ─────────────────────────
LOGROTATE_FILE="/etc/logrotate.d/shai-logs"
cat > "$LOGROTATE_FILE" <<EOF
$LOG_DIR/*.log {
    weekly
    rotate 4
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root root
}
EOF

# ────────────────────────────── Logging ───────────────────────────────────────
mkdir -p "$LOG_DIR"
exec > >(tee -a "$SETUP_LOG") 2>&1

echo "=== SHAI directory tree created at $SHAI_ROOT ==="

# ─────────────────────────── NVIDIA check ────────────────────────────────────
echo "=== Verifying NVIDIA driver inside WSL ==="
if ! nvidia-smi &>/dev/null; then
  echo "⚠️  nvidia-smi unavailable. Ensure Windows NVIDIA driver for WSL is installed." >&2
else
  nvidia-smi | head -n 3
fi

# ───────────────────────────── Finished ──────────────────────────────────────
echo "=== Setup completed ==="
if [[ ${USER_NEEDS_RELOGIN:-false} == true ]]; then
  echo "ℹ️  User '$CALLING_USER' added to group 'docker'. Please close and reopen your WSL session." >&2
fi

exit 0