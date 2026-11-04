#!/usr/bin/env bash
# =============================================================================
#  Run AFTER the txAdmin "QBox Framework" recipe has finished deploying.
#
#  Adds:
#    - vMenu Enhanced (locked down so it can't break the economy; modded cars and
#      guns show up in its admin menus)
#    - empty "custom_vehicles" and "custom_weapons" resources for your add-ons
#    - "no_npc_services": no NPC police, EMS or fire
#    - "glow_hud": the glowing HUD, which replaces qbx_hud
#    - "glow_loading": loading screen with mod credits, which replaces loadscreen
#    - private-server settings in server.cfg
#
#  Run ON THE LINUX SERVER as root:   sudo bash post-install.sh
#  If it can't find your server folder:  sudo bash post-install.sh /path/to/server/folder
#  Safe to run again (re-downloads vMenu, rewrites only its own server.cfg blocks).
# =============================================================================
set -euo pipefail

FIVEM_USER="fivem"
FIVEM_HOME="/home/${FIVEM_USER}"

log()  { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
die()  { printf '\n\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run this as root:  sudo bash post-install.sh"

# ----------------------------- find server folder ----------------------------
SERVER_DIR="${1:-}"
if [[ -z "$SERVER_DIR" ]]; then
  mapfile -t CANDIDATES < <(find "$FIVEM_HOME" -maxdepth 4 -name server.cfg -not -path '*/fxserver/alpine/*' -printf '%h\n')
  if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
    die "No server.cfg found under ${FIVEM_HOME}. Finish the txAdmin recipe first."
  elif [[ ${#CANDIDATES[@]} -gt 1 ]]; then
    printf 'Found more than one server folder:\n'; printf '  %s\n' "${CANDIDATES[@]}"
    die "Run again with the one you want:  sudo bash post-install.sh /path/to/folder"
  fi
  SERVER_DIR="${CANDIDATES[0]}"
fi
[[ -f "$SERVER_DIR/server.cfg" ]] || die "No server.cfg in $SERVER_DIR"
CUSTOM_DIR="$SERVER_DIR/resources/[custom]"
mkdir -p "$CUSTOM_DIR"
echo "Server folder: $SERVER_DIR"

# ----------------------------- vMenu -----------------------------------------
# vMenu is now "vMenu Enhanced". A regular FiveM server needs the zip with
# "Legacy" in its name, and the folder MUST be called vMenu.Enhanced.
log "Downloading latest vMenu Enhanced (Legacy build, for regular FiveM)"
VMENU_URL="$(curl -fsSL https://api.github.com/repos/TomGrobbe/vMenu/releases/latest \
  | jq -r '[.assets[] | select((.name | endswith(".zip")) and (.name | test("Legacy"))) | .browser_download_url][0] // empty')"
[[ "$VMENU_URL" == https://* ]] || die "Could not find the vMenu Legacy download (GitHub may be rate-limiting, try again later)."
echo "$VMENU_URL"

TMP="$(mktemp -d)"
curl -fL "$VMENU_URL" -o "$TMP/vmenu.zip"
unzip -q "$TMP/vmenu.zip" -d "$TMP/x"
MANIFEST="$(find "$TMP/x" -maxdepth 2 -name fxmanifest.lua | head -n1)"
[[ -n "$MANIFEST" ]] || die "vMenu zip layout not recognised."
VMENU_DIR="$CUSTOM_DIR/vMenu.Enhanced"
VMENU_CFG="$VMENU_DIR/config"

# Keep your own edited config files across updates
KEEP="$(mktemp -d)"
if [[ -d "$VMENU_CFG" ]]; then
  cp -a "$VMENU_CFG/." "$KEEP/"
fi
rm -rf "$VMENU_DIR"
cp -r "$(dirname "$MANIFEST")" "$VMENU_DIR"
for f in permissions.cfg configuration.cfg weapons.json; do
  if [[ -f "$KEEP/$f" ]]; then cp -a "$KEEP/$f" "$VMENU_CFG/$f"; fi
done
rm -rf "$TMP" "$KEEP"

# The old vMenu (v3.x) can't run next to this one. Move it out of the way.
OLD_VMENU="$(find "$SERVER_DIR/resources" -type f -path '*/vMenu/fxmanifest.lua' -print -quit || true)"
if [[ -n "$OLD_VMENU" ]]; then
  log "Moving the old vMenu to disabled-resources/"
  mkdir -p "$SERVER_DIR/disabled-resources"
  rm -rf "$SERVER_DIR/disabled-resources/vMenu"
  mv "$(dirname "$OLD_VMENU")" "$SERVER_DIR/disabled-resources/vMenu"
fi

# Permissions. Only written the first time, so your admin edits survive re-runs
if [[ ! -f "$VMENU_CFG/permissions.cfg" ]]; then
log "Writing vMenu permissions.cfg"
cat > "$VMENU_CFG/permissions.cfg" <<'EOF'
## =====================================================================
##  vMenu Enhanced permissions for a Qbox roleplay server
##  Admins get everything, INCLUDING the modded cars and guns (they show up
##  in Vehicle Spawner and Weapon Options on their own).
##  Everyone else only gets harmless settings, so vMenu can't be used to
##  skip the economy (free cars, guns, repairs).
## =====================================================================

## Lets vMenu add/remove permission groups itself (needed by some plugins)
add_ace resource.vMenu.Enhanced command.add_principal allow
add_ace resource.vMenu.Enhanced command.remove_principal allow

## ---- Admins ---------------------------------------------------------
add_ace group.admin "vMenu.Enhanced.Everything" allow

## Make yourself (and trusted friends) admin. Find identifiers in
## txAdmin > Players > click a player > IDs. Remove the "#" to enable.
## (Steam identifiers don't work any more, use fivem: or license:)
# add_principal identifier.fivem:1234567 group.admin
# add_principal identifier.license:abcdef1234567890 group.admin

## ---- Everyone -------------------------------------------------------
add_ace builtin.everyone "vMenu.Enhanced.Menus.MiscSettings.All" allow

## ---- Optional "fun mode" for everyone (remove "#" to enable) --------
## Warning: these let players skip mechanics, the customs shop, and dying.
## VehicleSpawner would also let everyone spawn the modded cars for free.
# add_ace builtin.everyone "vMenu.Enhanced.Menus.VehicleOptions.All" allow
# add_ace builtin.everyone "vMenu.Enhanced.Menus.PlayerOptions.All" allow
# add_ace builtin.everyone "vMenu.Enhanced.Menus.VehicleSpawner.All" allow
EOF
fi

# Settings. Copied from vMenu's own example the first time, with two changes
if [[ ! -f "$VMENU_CFG/configuration.cfg" ]]; then
log "Writing vMenu configuration.cfg"
cp "$VMENU_CFG/configuration.cfg.example" "$VMENU_CFG/configuration.cfg"
# Renewed-Weathersync controls weather and time, so vMenu must not
sed -i -E 's/^(setr vMenu\.Enhanced\.WeatherOptions\.Enabled) .*/\1 false/; s/^(setr vMenu\.Enhanced\.TimeOptions\.Enabled) .*/\1 false/' "$VMENU_CFG/configuration.cfg"
fi

# ----------------------------- custom vehicles template ----------------------
if [[ ! -f "$CUSTOM_DIR/custom_vehicles/fxmanifest.lua" ]]; then
  log "Creating custom_vehicles resource"
  mkdir -p "$CUSTOM_DIR/custom_vehicles/stream" "$CUSTOM_DIR/custom_vehicles/data"
  cat > "$CUSTOM_DIR/custom_vehicles/fxmanifest.lua" <<'EOF'
-- Add-on cars. Put each car's .yft/.ytd files in stream/<carname>/
-- and its .meta files in data/<carname>/  (any sub-folder name works)
fx_version 'cerulean'
game 'gta5'

files {
    'data/**/*.meta',
}

data_file 'HANDLING_FILE'            'data/**/handling.meta'
data_file 'VEHICLE_METADATA_FILE'    'data/**/vehicles.meta'
data_file 'CARCOLS_FILE'             'data/**/carcols.meta'
data_file 'VEHICLE_VARIATION_FILE'   'data/**/carvariations.meta'
data_file 'VEHICLE_LAYOUTS_FILE'     'data/**/vehiclelayouts.meta'
EOF
fi

# ----------------------------- custom weapons template -----------------------
if [[ ! -f "$CUSTOM_DIR/custom_weapons/fxmanifest.lua" ]]; then
  log "Creating custom_weapons resource"
  mkdir -p "$CUSTOM_DIR/custom_weapons/stream" "$CUSTOM_DIR/custom_weapons/meta"
  cat > "$CUSTOM_DIR/custom_weapons/fxmanifest.lua" <<'EOF'
-- Add-on guns. Put .ydr/.ytd model files in stream/
-- and the weapon's .meta files in meta/
-- Each new gun must ALSO be added to ox_inventory/data/weapons.lua (see guide).
fx_version 'cerulean'
game 'gta5'

files {
    'meta/**/*.meta',
}

data_file 'WEAPONCOMPONENTSINFO_FILE' 'meta/**/weaponcomponents.meta'
data_file 'WEAPON_METADATA_FILE'      'meta/**/weaponarchetypes.meta'
data_file 'WEAPON_ANIMATIONS_FILE'    'meta/**/weaponanimations.meta'
data_file 'PED_PERSONALITY_FILE'      'meta/**/pedpersonality.meta'
data_file 'WEAPONINFO_FILE'           'meta/**/weapons.meta'
EOF
fi

# ----------------------------- no NPC police / EMS / fire --------------------
log "Creating no_npc_services resource"
NPC_DIR="$CUSTOM_DIR/no_npc_services"
mkdir -p "$NPC_DIR"
cat > "$NPC_DIR/fxmanifest.lua" <<'EOF'
-- Removes NPC police, EMS and fire from the world.
-- Players with police/EMS jobs and their job vehicles are NOT affected.
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

shared_script 'config.lua'
client_script 'client.lua'
server_script 'server.lua'
EOF

cat > "$NPC_DIR/config.lua" <<'EOF'
-- Models that never spawn as NPCs (ambient traffic, parked at stations, dispatched).
-- Script-spawned ones (job garages, vMenu, admin spawns) still work.
BlockedModels = {
    -- police vehicles
    'police', 'police2', 'police3', 'police4', 'policeb', 'policet', 'policeold1', 'policeold2',
    'sheriff', 'sheriff2', 'fbi', 'fbi2', 'pranger', 'riot', 'riot2', 'polmav', 'predator',
    -- EMS / fire / lifeguard vehicles
    'ambulance', 'firetruk', 'lguard', 'blazer2',
    -- police peds
    's_m_y_cop_01', 's_f_y_cop_01', 's_m_y_sheriff_01', 's_f_y_sheriff_01', 's_m_y_hwaycop_01',
    's_m_y_swat_01', 's_m_m_snowcop_01', 's_m_y_ranger_01', 's_f_y_ranger_01',
    -- EMS / fire / lifeguard peds
    's_m_m_paramedic_01', 's_m_y_fireman_01', 's_m_y_baywatch_01', 's_f_y_baywatch_01',
}
EOF

cat > "$NPC_DIR/server.lua" <<'EOF'
local blocked = {}
for _, name in ipairs(BlockedModels) do
    blocked[GetHashKey(name) & 0xFFFFFFFF] = true
end

local MISSION = 7 -- population type of script-created entities (player job cars, garages, vMenu)

AddEventHandler('entityCreating', function(entity)
    if blocked[GetEntityModel(entity) & 0xFFFFFFFF] and GetEntityPopulationType(entity) ~= MISSION then
        CancelEvent()
    end
end)
EOF

cat > "$NPC_DIR/client.lua" <<'EOF'
local stationScenarios = {
    'WORLD_VEHICLE_POLICE_BIKE', 'WORLD_VEHICLE_POLICE_CAR', 'WORLD_VEHICLE_POLICE_NEXT_TO_CAR',
    'WORLD_VEHICLE_AMBULANCE', 'WORLD_VEHICLE_FIRE_TRUCK',
}

CreateThread(function()
    for _, name in ipairs(BlockedModels) do
        local hash = joaat(name)
        if IsModelAVehicle(hash) then
            SetVehicleModelIsSuppressed(hash, true)
        else
            SetPedModelIsSuppressed(hash, true)
        end
    end
    for _, scenario in ipairs(stationScenarios) do
        SetScenarioTypeEnabled(scenario, false)
    end
    SetCreateRandomCops(false)
    SetCreateRandomCopsNotOnScenarios(false)
    SetCreateRandomCopsOnScenarios(false)
    SetAudioFlag('PoliceScannerDisabled', true)
    SetMaxWantedLevel(0)

    -- The game turns some of these back on, so keep re-applying them
    while true do
        for service = 1, 15 do
            EnableDispatchService(service, false)
        end
        if GetPlayerWantedLevel(PlayerId()) > 0 then
            ClearPlayerWantedLevel(PlayerId())
        end
        Wait(1000)
    end
end)
EOF

# ----------------------------- glow_hud and glow_loading ---------------------
REPO_RESOURCES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/resources"

install_from_repo() {
  log "Installing $1"
  [[ -f "$REPO_RESOURCES/$1/fxmanifest.lua" ]] || die "Missing $REPO_RESOURCES/$1. Run this from the folder you cloned from GitHub."
  rm -rf "${CUSTOM_DIR:?}/$1"
  cp -r "$REPO_RESOURCES/$1" "$CUSTOM_DIR/$1"
}

# Moves a resource out of resources/, where FiveM can't load it, and comments out its server.cfg lines
disable_resource() {
  local manifest
  while IFS= read -r -d '' manifest; do
    mkdir -p "$SERVER_DIR/disabled-resources"
    rm -rf "${SERVER_DIR:?}/disabled-resources/$1"
    mv "$(dirname "$manifest")" "$SERVER_DIR/disabled-resources/$1"
    echo "Moved $1 to disabled-resources/"
  done < <(find "$SERVER_DIR/resources" -type f -path "*/$1/fxmanifest.lua" -print0)
  sed -i -E "s/^[[:space:]]*(ensure|start)[[:space:]]+$1[[:space:]]*\$/# &/" "$SERVER_DIR/server.cfg"
}

install_from_repo glow_hud
rm -f "$CUSTOM_DIR/glow_hud/html/preview.html"
disable_resource qbx_hud

install_from_repo glow_loading
disable_resource loadscreen
sed -i -E 's/^[[:space:]]*exec[[:space:]].*loadscreen\.cfg.*$/# &/' "$SERVER_DIR/server.cfg"

# ----------------------------- server.cfg ------------------------------------
log "Updating server.cfg"
CFG="$SERVER_DIR/server.cfg"
cp "$CFG" "$CFG.bak.$(date +%Y%m%d-%H%M%S)"
# Remove our managed blocks (this also clears the old v3 vMenu lines from earlier versions of this script)
sed -i '/^# >>> friends-setup/,/^# <<< friends-setup/d' "$CFG"
sed -i '/^# >>> vmenu-last/,/^# <<< vmenu-last/d' "$CFG"
cat >> "$CFG" <<'EOF'
# >>> friends-setup (managed by post-install.sh - edits inside this block are overwritten)
## Hide the server from the public FiveM server list (friends connect by IP)
sv_master1 ""

## Custom cars and guns
ensure custom_vehicles
ensure custom_weapons

## No NPC police, EMS or fire (players with those jobs still work)
ensure no_npc_services

## Glowing HUD (replaces qbx_hud)
ensure glow_hud

## Loading screen with mod credits (replaces loadscreen)
ensure glow_loading
# <<< friends-setup
EOF

# Mods installed by an older version of this script were added at the bottom, below vMenu.
# Move them above where vMenu is about to go.
python3 - "$CFG" <<'MIGRATE'
import os, sys
p = sys.argv[1]
mods_dir = os.path.join(os.path.dirname(p), 'resources', '[mods]')
mods = set(os.listdir(mods_dir)) if os.path.isdir(mods_dir) else set()
lines = open(p).read().split('\n')
move = [l for l in lines if l.strip().startswith('ensure ') and l.strip()[7:].strip() in mods]
if move:
    keep = [l for l in lines if l not in move]
    while keep and keep[-1] == '':
        keep.pop()
    open(p, 'w').write('\n'.join(keep + move) + '\n')
MIGRATE

# vMenu goes LAST, after every car and gun resource. add-mod.sh puts new mods
# just above the ">>> vmenu-last" line. vMenu has to start after them or their
# cars and guns don't show up in its menus.
cat >> "$CFG" <<'EOF'
# >>> vmenu-last (managed by post-install.sh - keep this at the very bottom)
## vMenu Enhanced - press M to open
exec @vMenu.Enhanced/config/permissions.cfg
exec @vMenu.Enhanced/config/configuration.cfg
add_filesystem_permission vMenu.Enhanced write vMenu.Enhanced
ensure vMenu.Enhanced
# <<< vmenu-last
EOF

# Put the modded guns in vMenu's Weapon Options
bash "$(dirname "${BASH_SOURCE[0]}")/vmenu-sync.sh" "$SERVER_DIR"

chown -R "${FIVEM_USER}:${FIVEM_USER}" "$SERVER_DIR"

log "Restarting server"
systemctl restart fivem

cat <<EOF

=====================================================================
 Done!
   vMenu:          $CUSTOM_DIR/vMenu.Enhanced
   Permissions:    $VMENU_CFG/permissions.cfg   <- add yourself as admin here
   Custom cars:    $CUSTOM_DIR/custom_vehicles
   Custom guns:    $CUSTOM_DIR/custom_weapons
   server.cfg backup saved next to server.cfg

 Next: in txAdmin > Settings > Player Manager, turn on the whitelist
 so only your friends can join.
=====================================================================
EOF
