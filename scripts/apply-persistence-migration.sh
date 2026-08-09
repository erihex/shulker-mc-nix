#!/usr/bin/env bash
set -euo pipefail

HOST="${HOST:-shulker-mc}"
SERVER_NAME="${SERVER_NAME:-shulker-atm}"
DATA_ROOT="${DATA_ROOT:-/srv/minecraft}"
SERVER_DIR="${DATA_ROOT}/${SERVER_NAME}"
SERVICE="minecraft-server-${SERVER_NAME}.service"
BACKUP_ROOT="${BACKUP_ROOT:-/var/backups/minecraft-persistence-migration}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="${BACKUP_ROOT}/${SERVER_NAME}-${TIMESTAMP}"

if [[ ${EUID} -ne 0 ]]; then
  echo "Run this script as root (for example: sudo ./scripts/apply-persistence-migration.sh)." >&2
  exit 1
fi

if [[ ! -f flake.nix ]]; then
  echo "Run this script from the repository root (flake.nix was not found)." >&2
  exit 1
fi

if [[ ! -d "${SERVER_DIR}" ]]; then
  echo "Minecraft server directory does not exist: ${SERVER_DIR}" >&2
  exit 1
fi

mkdir -p "${BACKUP_DIR}"
chmod 0700 "${BACKUP_DIR}"

persistent_trees=(
  config
  defaultconfigs
  kubejs
  datapacks
  tacz
)

echo "Building the new NixOS generation before touching the running service..."
nixos-rebuild build --flake "path:.#${HOST}"

echo "Backing up currently live nix-minecraft-managed runtime trees to: ${BACKUP_DIR}"
for tree in "${persistent_trees[@]}"; do
  if [[ -e "${SERVER_DIR}/${tree}" ]]; then
    cp -a "${SERVER_DIR}/${tree}" "${BACKUP_DIR}/${tree}"
  fi
done

# Keep the management manifest for post-migration diagnosis only.
if [[ -e "${SERVER_DIR}/.nix-minecraft-managed" ]]; then
  cp -a "${SERVER_DIR}/.nix-minecraft-managed" "${BACKUP_DIR}/nix-minecraft-managed.before"
fi

sync

echo "Switching to the new generation. The old unit may delete its managed trees once here; they are backed up."
nixos-rebuild switch --flake "path:.#${HOST}"

# The new unit may have already started and seeded defaults. Stop it cleanly,
# restore the live state over those defaults, then start it again.
echo "Stopping the server under the new ownership model before restoring live state..."
systemctl stop "${SERVICE}"

for tree in "${persistent_trees[@]}"; do
  if [[ -d "${BACKUP_DIR}/${tree}" ]]; then
    mkdir -p "${SERVER_DIR}/${tree}"
    cp -a "${BACKUP_DIR}/${tree}/." "${SERVER_DIR}/${tree}/"
  fi
done

chown -R minecraft:minecraft \
  "${SERVER_DIR}/config" \
  "${SERVER_DIR}/defaultconfigs" \
  "${SERVER_DIR}/kubejs" \
  "${SERVER_DIR}/datapacks" \
  "${SERVER_DIR}/tacz" 2>/dev/null || true

sync

echo "Starting ${SERVICE}..."
systemctl start "${SERVICE}"

echo
echo "Migration complete. Backup retained at: ${BACKUP_DIR}"
echo "Verify LoginSystem and OfflineWhitelist state, then keep the backup until you are satisfied."
