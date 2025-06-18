#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Echo Stack – Ubuntu Server bootstrap script (bare-metal / VM)
# -----------------------------------------------------------------------------
# Target : Ubuntu Server 22.04 LTS with an NVIDIA GPU (PCIe or passthrough)
# * Installs NVIDIA driver 550, Docker CE and the NVIDIA Container Toolkit
# * Creates /opt/echo directory tree + logrotate
# * Configures UFW (OpenSSH + OpenWebUI port)
# * Syncs project files from /opt/echo-src
# * English-only, non-interactive, idempotent
# -----------------------------------------------------------------------------
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# ───────────────────────── Variables ─────────────────────────────────────────
ECHO_ROOT="/opt/echo"
ECHO_SRC="/opt/echo-src"
LOG_DIR="$ECHO_ROOT/logs"
SETUP_LOG="$LOG_DIR/setup.log"
OPENWEBUI_PORT="8080"
CALLING_USER="$(logname)"

# ─────────────────── Ensure root privileges ──────────────────────────────────
if [[ "$EUID" -ne 0 ]]; then
  echo "🛑  Please run this script with sudo or as root." >&2
  exit 1
fi

# ─────────────────── System update & base packages ───────────────────────────
echo "=== System update ==="
apt-get update -y
apt-get full-upgrade -y

apt-get install -y \
  curl ca-certificates gnupg lsb-release \
  git htop unzip tmux logrotate ufw software-properties-common

# ───────────────────────── NVIDIA driver ─────────────────────────────────────
if ! command -v nvidia-smi &>/dev/null; then
  echo "=== Installing NVIDIA driver 550 ==="
  add-apt-repository -y ppa:graphics-drivers/ppa
  apt-get update -y
  apt-get install -y nvidia-driver-550
  NEEDS_REBOOT=true
fi

# ───────────────────────── Docker CE ─────────────────────────────────────────
if ! command -v docker &>/dev/null; then
  echo "=== Installing Docker CE ==="
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io \
                     docker-buildx-plugin docker-compose-plugin
fi

# ───────────── NVIDIA Container Toolkit (generic deb repo) ───────────────────
if ! command -v nvidia-ctk &>/dev/null; then
  echo "=== Installing NVIDIA Container Toolkit ==="
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
    | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

  curl -sSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#' \
    > /etc/apt/sources.list.d/nvidia-container-toolkit.list

  apt-get update -y
  apt-get install -y nvidia-container-toolkit
  nvidia-ctk runtime configure --runtime=docker
fi

systemctl enable --now docker

# ─────────── Add user to docker group ────────────────────────────────────────
if ! id -nG "$CALLING_USER" | grep -qw docker; then
  usermod -aG docker "$CALLING_USER"
  USER_NEEDS_RELOGIN=true
fi

# ────────────────── Create Echo directory structure ──────────────────────────
mkdir -p "$ECHO_ROOT"/bin "$ECHO_ROOT"/models "$ECHO_ROOT"/vllm \
         "$ECHO_ROOT"/openwebui/data "$LOG_DIR"
chown -R "$CALLING_USER:$CALLING_USER" "$ECHO_ROOT"

# ──────────────── Initialize logrotate configuration ─────────────────────────
cat > /etc/logrotate.d/echo-logs <<EOF
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

# ───────────────────────── Sync Echo project source ──────────────────────────
echo "=== Syncing Echo project files ==="
if [[ -d "$ECHO_SRC" ]]; then
  rsync -a --exclude='.git' "$ECHO_SRC"/ "$ECHO_ROOT"/
  chown -R "$CALLING_USER:$CALLING_USER" "$ECHO_ROOT"
  chmod +x "$ECHO_ROOT"/bin/*.sh || true
else
  echo "⚠️  $ECHO_SRC not found. Skipping rsync of project files." >&2
fi

# ────────────────────────────── Logging ───────────────────────────────────────
mkdir -p "$LOG_DIR"
exec > >(tee -a "$SETUP_LOG") 2>&1

echo "=== Echo directory tree created at $ECHO_ROOT ==="

# ──────────────────────────── UFW rules ───────────────────────────────────────
if ufw status | grep -q inactive; then
  echo "=== Enabling UFW ==="
  ufw allow OpenSSH
  ufw allow ${OPENWEBUI_PORT}/tcp comment "OpenWebUI"
  ufw --force enable
fi

# ───────────────────────── NVIDIA check ───────────────────────────────────────
if nvidia-smi &>/dev/null; then
  nvidia-smi | head -n 3
else
  echo "⚠️  NVIDIA driver will be active after reboot." >&2
fi

# ───────────────────────────── Finished ───────────────────────────────────────
echo "=== Setup completed ==="
if [[ ${USER_NEEDS_RELOGIN:-false} == true ]]; then
  echo "ℹ️  User '$CALLING_USER' added to group 'docker'. Please log out and back in." >&2
fi
if [[ ${NEEDS_REBOOT:-false} == true ]]; then
  echo "🔄  A reboot is required to load the NVIDIA driver." >&2
fi

exit 0