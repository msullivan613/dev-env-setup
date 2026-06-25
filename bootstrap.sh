#!/usr/bin/env bash
#
# bootstrap.sh — entrypoint for a fresh machine.
#
# Installs Ansible (if missing) and runs the playbook against localhost.
# Primes the sudo credential cache up front (works with password or YubiKey
# sudo), so the playbook runs without --ask-become-pass.
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

# --- Authenticate sudo ------------------------------------------------------
# We don't pass --ask-become-pass to ansible-playbook: that makes Ansible feed
# a password to sudo over stdin, which breaks where sudo authenticates some
# other way (e.g. a YubiKey touch via pam_u2f). Instead, prime sudo's
# credential cache interactively here — this honors whatever PAM requires
# (password, touch, etc.) — then let Ansible's become ride the cached
# timestamp. A background refresher keeps the timestamp alive so a long run
# doesn't expire mid-playbook.
log "Authenticating sudo (touch your security key / enter your password if prompted)..."
sudo -v

while true; do
  sudo -n true 2>/dev/null || exit
  sleep 50
done &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT

# --- Run the playbook -------------------------------------------------------
log "Running playbook..."
ansible-playbook -i inventory.ini site.yml "$@"
