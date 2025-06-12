#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# SHAI Stack – WSL 2 bootstrap script (mise à jour)
# ----------------------------------------------------------------------------
# Installe Docker + NVIDIA Toolkit (WSL2), configure /opt/shai proprement
# ----------------------------------------------------------------------------
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Variables principales
SHAI_ROOT="/opt/shai"
LOG_DIR="$SHAI_ROOT/logs"
SETUP_LOG="$LOG_DIR/setup.log"
CALLING_USER="$(logname)"

# Assurer droits root
if [[ "$EUID" -ne 0 ]]; then
  echo "🛑  Exécute ce script avec sudo ou en tant que root." >&2
  exit 1
fi

# Mise à jour système + dépendances de base
echo "=== Mise à jour du système ==="
apt-get update -y
apt-get full-upgrade -y

apt-get install -y \
  curl ca-certificates gnupg lsb-release \
  git htop unzip tmux logrotate python3-venv pipx make

# Docker CE (si manquant)
if ! command -v docker &>/dev/null; then
  echo "=== Installation de Docker CE ==="
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

# NVIDIA Container Toolkit (version WSL2)
if ! command -v nvidia-ctk &>/dev/null; then
  echo "=== Installation NVIDIA Container Toolkit ==="

  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
    | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

  curl -sSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#' \
    > /etc/apt/sources.list.d/nvidia-container-toolkit.list

  apt-get update -y
  apt-get install -y nvidia-container-toolkit

  nvidia-ctk runtime configure --runtime=docker
fi

# Redémarrage du service Docker
systemctl restart docker || echo "ℹ️  docker n'est pas géré par systemd sous WSL2, ignore si docker fonctionne."

# Ajout au groupe docker si besoin
if ! id -nG "$CALLING_USER" | grep -qw docker; then
  usermod -aG docker "$CALLING_USER"
  echo "ℹ️  L'utilisateur '$CALLING_USER' a été ajouté au groupe docker. Reconnecte ta session." >&2
fi

# Création de l'arborescence SHAI
mkdir -p "$SHAI_ROOT"/{bin,models,vllm,openwebui/data,logs}
chown -R "$CALLING_USER:$CALLING_USER" "$SHAI_ROOT"

# logrotate
cat > /etc/logrotate.d/shai-logs <<EOF
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

# Création du fichier .env si absent
touch "$SHAI_ROOT/.env"
chown "$CALLING_USER:$CALLING_USER" "$SHAI_ROOT/.env"

# Initialisation du log
mkdir -p "$LOG_DIR"
echo "=== Setup log ===" > "$SETUP_LOG"
echo "$(date -u) – SHAI WSL2 setup completed" >> "$SETUP_LOG"

# NVIDIA test via conteneur Docker
echo "=== Test NVIDIA via Docker ==="
if docker run --rm --gpus all nvidia/cuda:12.3.0-devel-ubuntu22.04 nvidia-smi &>/dev/null; then
  docker run --rm --gpus all nvidia/cuda:12.3.0-devel-ubuntu22.04 nvidia-smi | head -n 10
else
  echo "⚠️  GPU Docker non accessible – vérifie les drivers Windows et WSL." >&2
fi

exit 0
