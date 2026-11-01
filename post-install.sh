#!/usr/bin/env bash
# =============================================================================
#  Run AFTER the txAdmin "QBox Framework" recipe has finished deploying.
#
#  Adds:
#    - vMenu (locked down so it can't break the economy)
#    - empty "custom_vehicles" and "custom_weapons" resources for your add-ons
#    - "no_npc_services": no NPC police, EMS or fire
#    - "glow_hud": the glowing HUD, which replaces qbx_hud
#    - private-server settings in server.cfg
#
#  Run ON THE LINUX SERVER as root:   sudo bash post-install.sh
#  If it can't find your server folder:  sudo bash post-install.sh /path/to/server/folder
#  Safe to run again (re-downloads vMenu, rewrites only its own server.cfg block).
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
log "Downloading latest vMenu release"
VMENU_URL="$(curl -fsSL https://api.github.com/repos/TomGrobbe/vMenu/releases/latest \
  | jq -r '.assets[] | select(.name | endswith(".zip")) | .browser_download_url' | head -n1)"
[[ "$VMENU_URL" == https://* ]] || die "Could not find the vMenu download (GitHub may be rate-limiting, try again later)."
echo "$VMENU_URL"

TMP="$(mktemp -d)"
curl -fL "$VMENU_URL" -o "$TMP/vmenu.zip"
unzip -q "$TMP/vmenu.zip" -d "$TMP/x"
MANIFEST="$(find "$TMP/x" \( -name fxmanifest.lua -o -name __resource.lua \) | head -n1)"
[[ -n "$MANIFEST" ]] || die "vMenu zip layout not recognised."
rm -rf "$CUSTOM_DIR/vMenu"
cp -r "$(dirname "$MANIFEST")" "$CUSTOM_DIR/vMenu"
rm -rf "$TMP"

# Only written the first time, so your admin edits survive re-runs
if [[ ! -f "$SERVER_DIR/vmenu_permissions.cfg" ]]; then
log "Writing vmenu_permissions.cfg"
cat > "$SERVER_DIR/vmenu_permissions.cfg" <<'EOF'
## =====================================================================
##  vMenu permissions for a Qbox roleplay server
##  Admins get everything. Everyone else only gets harmless settings, so
##  vMenu can't be used to skip the economy (free cars, guns, repairs).
## =====================================================================

## ---- Admins ---------------------------------------------------------
add_ace group.admin vMenu.Everything allow

## Make yourself (and trusted friends) admin. Find identifiers in
## txAdmin > Players > click a player > IDs. Remove the "#" to enable.
# add_principal identifier.fivem:1234567 group.admin
# add_principal identifier.license:abcdef1234567890 group.admin

## ---- Everyone -------------------------------------------------------
add_ace builtin.everyone vMenu.MiscSettings.All allow

## ---- Optional "fun mode" for everyone (remove "#" to enable) --------
## Warning: these let players skip mechanics, the customs shop, and dying.
# add_ace builtin.everyone vMenu.VehicleOptions.All allow
# add_ace builtin.everyone vMenu.PlayerOptions.All allow
# add_ace builtin.everyone vMenu.NoClip allow
EOF
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

# ----------------------------- glow_hud (replaces qbx_hud) -------------------
log "Installing glow_hud"
HUD_SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/resources/glow_hud"
[[ -f "$HUD_SOURCE/fxmanifest.lua" ]] || die "Missing $HUD_SOURCE. Run this from the folder you cloned from GitHub."
rm -rf "$CUSTOM_DIR/glow_hud"
cp -r "$HUD_SOURCE" "$CUSTOM_DIR/glow_hud"
rm -f "$CUSTOM_DIR/glow_hud/html/preview.html"

# Two HUDs would fight over the screen, so qbx_hud moves out of resources/ where FiveM can't load it
while IFS= read -r -d '' OLD_HUD; do
  mkdir -p "$SERVER_DIR/disabled-resources"
  rm -rf "$SERVER_DIR/disabled-resources/qbx_hud"
  mv "$OLD_HUD" "$SERVER_DIR/disabled-resources/qbx_hud"
  echo "Moved qbx_hud to disabled-resources/"
done < <(find "$SERVER_DIR/resources" -type d -name qbx_hud -print0)
sed -i -E 's/^[[:space:]]*(ensure|start)[[:space:]]+qbx_hud[[:space:]]*$/# &/' "$SERVER_DIR/server.cfg"

# ----------------------------- server.cfg ------------------------------------
log "Updating server.cfg"
CFG="$SERVER_DIR/server.cfg"
cp "$CFG" "$CFG.bak.$(date +%Y%m%d-%H%M%S)"
sed -i '/^# >>> friends-setup/,/^# <<< friends-setup/d' "$CFG"
cat >> "$CFG" <<'EOF'
# >>> friends-setup (managed by post-install.sh - edits inside this block are overwritten)
## Hide the server from the public FiveM server list (friends connect by IP)
sv_master1 ""

## vMenu - press M to open
setr vmenu_use_permissions true
setr vmenu_menu_staff_only false
setr vmenu_menu_toggle_key 244
setr vmenu_enable_weather_sync false
setr vmenu_enable_time_sync false
exec vmenu_permissions.cfg
ensure vMenu

## Custom cars and guns
ensure custom_vehicles
ensure custom_weapons

## No NPC police, EMS or fire (players with those jobs still work)
ensure no_npc_services

## Glowing HUD (replaces qbx_hud)
ensure glow_hud
# <<< friends-setup
EOF

chown -R "${FIVEM_USER}:${FIVEM_USER}" "$SERVER_DIR"

log "Restarting server"
systemctl restart fivem

cat <<EOF

=====================================================================
 Done!
   vMenu:          $CUSTOM_DIR/vMenu
   Permissions:    $SERVER_DIR/vmenu_permissions.cfg   <- add yourself as admin here
   Custom cars:    $CUSTOM_DIR/custom_vehicles
   Custom guns:    $CUSTOM_DIR/custom_weapons
   server.cfg backup saved next to server.cfg

 Next: in txAdmin > Settings > Player Manager, turn on the whitelist
 so only your friends can join.
=====================================================================
EOF
