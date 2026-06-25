#!/usr/bin/env bash
#
# bootstrap.sh — entrypoint for a fresh machine.
#
# Installs Ansible (if missing) and runs the playbook against localhost.
#
# Usage:
#   git clone <repo> ~/dev-env-setup
#   cd ~/dev-env-setup
#   ./bootstrap.sh [ansible-playbook args...]
#
# Examples:
#   ./bootstrap.sh                      # run everything
#   ./bootstrap.sh --tags shell,cli     # run only selected roles
#   ./bootstrap.sh --check              # dry run
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

log() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
err() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; }

if [ "$(id -u)" -eq 0 ]; then
  err "Do not run bootstrap.sh as root. Run as your normal user; it will sudo when needed."
  exit 1
fi

# --- Ensure sudo is available -----------------------------------------------
if ! command -v sudo >/dev/null 2>&1; then
  err "sudo is required but not installed."
  exit 1
fi

# --- Install Ansible --------------------------------------------------------
if ! command -v ansible-playbook >/dev/null 2>&1; then
  log "Ansible not found — installing via apt..."
  sudo apt-get update
  sudo apt-get install -y software-properties-common
  sudo apt-get install -y ansible
else
  log "Ansible already installed: $(ansible --version | head -n1)"
fi

# --- Run the playbook -------------------------------------------------------
log "Running playbook (you will be prompted for your sudo/BECOME password)..."
exec ansible-playbook -i inventory.ini site.yml --ask-become-pass "$@"
