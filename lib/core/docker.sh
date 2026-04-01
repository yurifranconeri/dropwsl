#!/usr/bin/env bash
# lib/core/docker.sh -- Installs Docker Engine, Compose v2 and BuildX.
# Requires: common.sh sourced

[[ -n "${_DOCKER_SH_LOADED:-}" ]] && return 0
_DOCKER_SH_LOADED=1

install_docker() {
  if has_cmd docker && docker compose version >/dev/null 2>&1; then
    log "Docker already installed: $(docker --version || true)"
    return 0
  fi

  log "Installing Docker Engine (official Docker repo) + Compose v2 plugin"
  get_distro_info

  local docker_gpg_tmp
  docker_gpg_tmp="$(make_temp)"
  curl_retry -fsSL -o "$docker_gpg_tmp" "https://download.docker.com/linux/${DISTRO_ID}/gpg"
  sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg < "$docker_gpg_tmp"
  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/${DISTRO_ID} ${DISTRO_CODENAME} stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

  run_quiet sudo apt-get update
  run_quiet sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-buildx-plugin \
    || die_hint "Failed to install Docker packages." \
      "Codename '${DISTRO_CODENAME}' not supported by Docker repository;Network or proxy issue;Docker repository unavailable" \
      "Check: https://download.docker.com/linux/${DISTRO_ID}/dists/ if '${DISTRO_CODENAME}' exists;Run: sudo apt-get update && sudo apt-get install -y docker-ce" \
      "curl -fsSL https://download.docker.com/linux/${DISTRO_ID}/dists/"

  log "Enabling and starting Docker service"
  run_quiet sudo systemctl enable docker
  run_quiet sudo systemctl start docker

  # daemon.json: MTU avoids fragmentation on VPN/WSL mirrored networking.
  # Default MTU (1500) exceeds VPN tunnel effective MTU (~1400),
  # causing packet loss and timeout on large downloads (pip wheels, npm packages).
  # Log rotation: prevents unbounded log growth that fills the WSL VHDX.
  # Without limits, a verbose container can generate GBs of logs in days.
  # Values configurable via config.yaml (core.docker.mtu, log_max_size, log_max_file).
  if [[ ! -f /etc/docker/daemon.json ]]; then
    log "Configuring /etc/docker/daemon.json (MTU ${DOCKER_MTU}, log rotation ${DOCKER_LOG_MAX_SIZE}x${DOCKER_LOG_MAX_FILE})"
    sudo tee /etc/docker/daemon.json >/dev/null <<DAEMON
{
  "mtu": ${DOCKER_MTU},
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "${DOCKER_LOG_MAX_SIZE}",
    "max-file": "${DOCKER_LOG_MAX_FILE}"
  }
}
DAEMON
    run_quiet sudo systemctl restart docker
  else
    if ! grep -q '"mtu"' /etc/docker/daemon.json; then
      warn "daemon.json exists but lacks MTU setting -- VPN users may see timeouts. Recommended: \"mtu\": ${DOCKER_MTU}"
    fi
    if ! grep -q '"log-driver"' /etc/docker/daemon.json; then
      warn "daemon.json exists but lacks log rotation -- logs may grow unbounded"
    fi
  fi

  # Wait for Docker to be ready (systemctl start returns before daemon accepts connections)
  local docker_wait=0
  while ! sudo docker info >/dev/null 2>&1; do
    if (( docker_wait >= 15 )); then
      warn "Docker daemon did not respond after 15s -- continuing"
      break
    fi
    sleep 1
    ((docker_wait++)) || true
  done

  if ! id -nG "$USER" | grep -qw docker; then
    log "Adding $USER to docker group (to run without sudo)"
    sudo usermod -aG docker "$USER"
  fi
}
