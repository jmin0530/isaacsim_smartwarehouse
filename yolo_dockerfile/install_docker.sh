#!/usr/bin/env bash
# One-time setup: install Docker CE + NVIDIA Container Toolkit on Ubuntu 22.04.
# Run once on the host before ./run.sh build.
#
# Usage:
#   ./install_docker.sh
#
# Safe to re-run — each step skips if already done.
# Requires sudo; you will be prompted.

set -euo pipefail

log() { echo -e "\n\033[1;36m==> $*\033[0m"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
err() { echo -e "\033[1;31m[ERR]\033[0m $*" >&2; }

# ---------------------------------------------------------------------------
# 0. Sanity
# ---------------------------------------------------------------------------
if [[ "$(. /etc/os-release && echo "$ID")" != "ubuntu" ]]; then
    err "This script targets Ubuntu. Detected: $(. /etc/os-release && echo "$ID $VERSION_ID")"
    exit 1
fi

if ! command -v nvidia-smi >/dev/null; then
    err "nvidia-smi not found. Install NVIDIA driver before running this."
    exit 1
fi

log "Detected GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)"

# ---------------------------------------------------------------------------
# 1. Docker CE
# ---------------------------------------------------------------------------
if command -v docker >/dev/null; then
    log "Docker already installed: $(docker --version)"
else
    log "Installing Docker (docker.io from Ubuntu repo)"
    sudo apt-get update
    sudo apt-get install -y docker.io
    sudo systemctl enable --now docker
fi

# ---------------------------------------------------------------------------
# 2. Add current user to docker group (avoids sudo for `docker` cmd)
# ---------------------------------------------------------------------------
if id -nG "$USER" | grep -qw docker; then
    log "User '$USER' already in docker group"
else
    log "Adding user '$USER' to docker group"
    sudo usermod -aG docker "$USER"
    DOCKER_GROUP_ADDED=1
fi

# ---------------------------------------------------------------------------
# 3. NVIDIA Container Toolkit (for --gpus all)
# ---------------------------------------------------------------------------
if dpkg -l | grep -qw nvidia-container-toolkit; then
    log "nvidia-container-toolkit already installed"
else
    log "Installing NVIDIA Container Toolkit"
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
        | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
        | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
        | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null
    sudo apt-get update
    sudo apt-get install -y nvidia-container-toolkit
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker
fi

# ---------------------------------------------------------------------------
# 4. Smoke test (only if docker group already active in this shell)
# ---------------------------------------------------------------------------
if id -nG | grep -qw docker; then
    log "Running GPU smoke test in container"
    if docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi; then
        log "Success — Docker + GPU passthrough working"
    else
        err "GPU smoke test failed. Inspect 'docker info' and 'nvidia-ctk runtime configure'."
        exit 1
    fi
else
    warn "Docker group not active in current shell."
    warn "Open a new terminal (or run 'newgrp docker'), then verify:"
    warn "  docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi"
fi

if [[ "${DOCKER_GROUP_ADDED:-0}" == "1" ]]; then
    log "Reminder: log out / log back in (or 'newgrp docker') for group change to take effect."
fi
