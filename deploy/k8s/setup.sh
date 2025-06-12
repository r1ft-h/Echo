#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# SHAI Stack – Kubernetes bootstrap script
# -----------------------------------------------------------------------------
# Target : Ubuntu Server 22.04 LTS with NVIDIA driver already installed
# * Installs k3s (lightweight Kubernetes)
# * Installs Helm package manager
# * Creates /opt/shai directory tree + logrotate
# * Syncs Kubernetes manifests from /opt/shai-src
# * Non-interactive and idempotent
# -----------------------------------------------------------------------------
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

SHAI_ROOT="/opt/shai"
SHAI_SRC="/opt/shai-src"
LOG_DIR="$SHAI_ROOT/logs"
SETUP_LOG="$LOG_DIR/setup.log"
CALLING_USER="$(logname)"

# Ensure root privileges
if [[ "$EUID" -ne 0 ]]; then
  echo "🛑  Please run this script with sudo or as root." >&2
  exit 1
fi

# System update & base packages
echo "=== System update ==="
apt-get update -y
apt-get full-upgrade -y

apt-get install -y \
  curl ca-certificates gnupg lsb-release \
  git htop unzip tmux logrotate

# Install k3s if missing
if ! command -v k3s &>/dev/null; then
  echo "=== Installing k3s ==="
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode=644" sh -
  NEEDS_REBOOT=true
fi

# Install Helm if missing
if ! command -v helm &>/dev/null; then
  echo "=== Installing Helm ==="
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Directory structure
mkdir -p "$SHAI_ROOT"/k8s "$LOG_DIR"
chown -R "$CALLING_USER:$CALLING_USER" "$SHAI_ROOT"

# Logrotate config
cat > /etc/logrotate.d/shai-logs <<EOF2
$LOG_DIR/*.log {
    weekly
    rotate 4
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root root
}
EOF2

# Sync project files if available
echo "=== Syncing SHAI project files ==="
if [[ -d "$SHAI_SRC" ]]; then
  rsync -a --exclude='.git' "$SHAI_SRC"/deploy/k8s/ "$SHAI_ROOT"/k8s/
  chown -R "$CALLING_USER:$CALLING_USER" "$SHAI_ROOT"
else
  echo "⚠️  $SHAI_SRC not found. Skipping rsync of project files." >&2
fi

# Initialize log
mkdir -p "$LOG_DIR"
exec > >(tee -a "$SETUP_LOG") 2>&1

echo "=== SHAI Kubernetes setup completed ==="
if [[ ${NEEDS_REBOOT:-false} == true ]]; then
  echo "🔄  A reboot may be required to finalise k3s installation." >&2
fi

exit 0
