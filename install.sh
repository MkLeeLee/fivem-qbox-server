#!/usr/bin/env bash
# =============================================================================
#  Qbox + txAdmin FiveM server - Linux installer
#  Tested target: Ubuntu 22.04 / 24.04 or Debian 12 (fresh VPS)
#
#  Run ON THE LINUX SERVER as root:   sudo bash install.sh
#  Safe to run again later: it updates the FiveM server files to the newest
#  recommended build and keeps your database and txData.
# =============================================================================
set -euo pipefail

# ----------------------------- settings --------------------------------------
FIVEM_USER="fivem"
FIVEM_HOME="/home/${FIVEM_USER}"
FX_DIR="${FIVEM_HOME}/fxserver"        # FiveM server binaries (artifacts)
TXDATA_DIR="${FIVEM_HOME}/txData"      # txAdmin data + your server files
DB_USER="qbox"
DB_NAME="qbox"
MARIADB_VERSION="11.4"                 # Qbox needs MariaDB 10.9+ (MySQL is NOT supported)
ARTIFACT_CHANNEL="recommended"         # "recommended" (stable) or "latest"
OPEN_FIREWALL="yes"                    # add ufw rules for FiveM + txAdmin ports
CRED_FILE="/root/fivem-db-credentials.txt"
# -----------------------------------------------------------------------------

log()  { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mWARNING: %s\033[0m\n' "$*"; }
die()  { printf '\n\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run this as root:  sudo bash install.sh"

. /etc/os-release
case "${ID}-${VERSION_ID}" in
  ubuntu-22.04|ubuntu-24.04|debian-12) ;;
  *) warn "Tested on Ubuntu 22.04/24.04 and Debian 12. You have ${PRETTY_NAME}. Continuing anyway." ;;
esac

# ----------------------------- packages --------------------------------------
log "Installing system packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl ca-certificates gnupg xz-utils tar unzip git jq openssl

# ----------------------------- MariaDB ---------------------------------------
if ! command -v mariadb >/dev/null 2>&1; then
  log "Installing MariaDB ${MARIADB_VERSION} (official MariaDB repo)"
  curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup \
    | bash -s -- --mariadb-server-version="mariadb-${MARIADB_VERSION}"
  apt-get update -y
  apt-get install -y mariadb-server mariadb-client
else
  log "MariaDB already installed"
fi
systemctl enable --now mariadb

DB_VERSION="$(mariadb -N -e 'SELECT VERSION();' | cut -d- -f1)"
if [[ "$(printf '%s\n10.9.0\n' "$DB_VERSION" | sort -V | head -n1)" != "10.9.0" ]]; then
  die "MariaDB ${DB_VERSION} is too old for Qbox (needs 10.9+). Remove it and re-run this script."
fi
echo "MariaDB version: ${DB_VERSION}"

log "Creating database '${DB_NAME}' and user '${DB_USER}'"
if [[ -f "$CRED_FILE" ]]; then
  DB_PASS="$(grep '^password=' "$CRED_FILE" | cut -d= -f2-)"
else
  DB_PASS="$(openssl rand -hex 16)"
fi
mariadb <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
ALTER USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
-- Covers "qbox" and any "qbox_xxxx" name the txAdmin deployer may suggest
GRANT ALL PRIVILEGES ON \`qbox%\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL
cat > "$CRED_FILE" <<EOF
host=localhost
port=3306
user=${DB_USER}
password=${DB_PASS}
database=${DB_NAME}
EOF
chmod 600 "$CRED_FILE"

# ----------------------------- fivem user ------------------------------------
if ! id -u "$FIVEM_USER" >/dev/null 2>&1; then
  log "Creating Linux user '${FIVEM_USER}'"
  useradd -m -s /bin/bash "$FIVEM_USER"
fi

# ----------------------------- FiveM artifacts -------------------------------
if systemctl is-active --quiet fivem 2>/dev/null; then
  log "Stopping running FiveM server for update"
  systemctl stop fivem
fi

log "Downloading FiveM Linux server (${ARTIFACT_CHANNEL} build)"
ARTIFACT_URL="$(curl -fsSL https://changelogs-live.fivem.net/api/changelog/versions/linux/server \
  | jq -r ".${ARTIFACT_CHANNEL}_download")"
[[ "$ARTIFACT_URL" == https://* ]] || die "Could not find the FiveM download link. Try again in a few minutes."
echo "$ARTIFACT_URL"

TMP_TAR="$(mktemp --suffix=.tar.xz)"
curl -fL "$ARTIFACT_URL" -o "$TMP_TAR"
# Only replace the old binaries; never touch anything else in FX_DIR
rm -rf "${FX_DIR}/alpine"
mkdir -p "${FX_DIR}" "${TXDATA_DIR}"
tar -xJf "$TMP_TAR" -C "${FX_DIR}"
rm -f "$TMP_TAR"
chown -R "${FIVEM_USER}:${FIVEM_USER}" "${FIVEM_HOME}"

# ----------------------------- systemd service -------------------------------
log "Creating systemd service 'fivem' (starts txAdmin on boot)"
cat > /etc/systemd/system/fivem.service <<EOF
[Unit]
Description=FiveM server (txAdmin + Qbox)
After=network-online.target mariadb.service
Wants=network-online.target

[Service]
Type=simple
User=${FIVEM_USER}
WorkingDirectory=${FX_DIR}
Environment=TXHOST_DATA_PATH=${TXDATA_DIR}
ExecStart=${FX_DIR}/run.sh
Restart=on-failure
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now fivem

# ----------------------------- firewall --------------------------------------
if [[ "$OPEN_FIREWALL" == "yes" ]] && command -v ufw >/dev/null 2>&1; then
  log "Adding firewall rules (ufw)"
  ufw allow OpenSSH >/dev/null 2>&1 || ufw allow 22/tcp
  ufw allow 30120/tcp     # game
  ufw allow 30120/udp     # game
  ufw allow 40120/tcp     # txAdmin web panel
  if ufw status | grep -q inactive; then
    warn "ufw is installed but turned off. Rules are saved; it stays off so you can't get locked out."
  fi
fi

# ----------------------------- done ------------------------------------------
PUBLIC_IP="$(curl -4 -fsS --max-time 5 https://api.ipify.org || hostname -I | awk '{print $1}')"
sleep 8
PIN_LINE="$(journalctl -u fivem --no-pager -n 200 | grep -iE 'pin' | tail -n 3 || true)"

cat <<EOF

=====================================================================
 Done! FiveM + txAdmin is running.

 1) Open txAdmin in your browser:   http://${PUBLIC_IP}:40120

 2) txAdmin asks for a PIN. Recent log lines with the PIN:
${PIN_LINE:-    (not shown yet - run:  journalctl -u fivem -n 50 --no-pager)}

 3) In the setup wizard choose:  Popular Recipes -> QBox Framework
    Database settings to type in:
       Host:     localhost
       Port:     3306
       Username: ${DB_USER}
       Password: ${DB_PASS}
       Database: ${DB_NAME}
    (saved in ${CRED_FILE})

 Useful commands:
   systemctl restart fivem          restart everything
   journalctl -u fivem -f           live server console/log
=====================================================================
EOF
