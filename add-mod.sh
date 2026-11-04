#!/usr/bin/env bash
# =============================================================================
#  Add a GTA V mod (map, props, textures, clothing, FiveM resource) to the
#  Qbox server. Downloads straight onto the server - nothing touches your PC.
#
#  Run ON THE LINUX SERVER as root:
#    sudo bash add-mod.sh inspect <name> "<direct-download-link>"
#        Download + unpack and show what's inside. Changes nothing.
#    sudo bash add-mod.sh install <name> ["<direct-download-link>"]
#        Turn it into a FiveM resource in resources/[mods]/ and add it to server.cfg.
#        Leave out the link to install what you last inspected.
#    sudo bash add-mod.sh remove <name>
#        Take it out again.
#
#  <name> = short name, lowercase letters/numbers/underscores, e.g. nz_flags
#
#  Nothing inside a download is ever run. Mods that contain scripts are not
#  installed unless you add --allow-scripts (have them checked first).
# =============================================================================
set -euo pipefail

FIVEM_USER="fivem"
FIVEM_HOME="/home/${FIVEM_USER}"
STAGING="${FIVEM_HOME}/mod-staging"
INSTALLED_DB="${STAGING}/.installed"
# File types FiveM can stream straight from a resource's stream/ folder
STREAM_EXT_REGEX='.*\.(ytd|ydr|ydd|yft|ybn|ymap|ytyp|ycd|ypt)$'

log()  { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mWARNING: %s\033[0m\n' "$*"; }
die()  { printf '\n\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

usage() {
  sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
}

[[ $EUID -eq 0 ]] || die "Run this as root:  sudo bash add-mod.sh ..."

ALLOW_SCRIPTS="no"
ARGS=()
for a in "$@"; do
  if [[ "$a" == "--allow-scripts" ]]; then ALLOW_SCRIPTS="yes"; else ARGS+=("$a"); fi
done
ACTION="${ARGS[0]:-}"
NAME="${ARGS[1]:-}"
URL="${ARGS[2]:-}"

[[ -n "$ACTION" && -n "$NAME" ]] || usage
[[ "$NAME" =~ ^[a-z0-9_]+$ ]] || die "Name must be lowercase letters, numbers and _ only (e.g. nz_flags)."

MOD_DIR="${STAGING}/${NAME}"
FILES="${MOD_DIR}/files"

# ----------------------------- helpers ---------------------------------------
find_server_dir() {
  local candidates
  mapfile -t candidates < <(find "$FIVEM_HOME" -maxdepth 4 -name server.cfg \
    -not -path '*/fxserver/*' -not -path "${STAGING}/*" -printf '%h\n')
  [[ ${#candidates[@]} -eq 1 ]] || die "Expected exactly one server.cfg under ${FIVEM_HOME}, found ${#candidates[@]}."
  SERVER_DIR="${candidates[0]}"
  RES_ROOT="${SERVER_DIR}/resources/[mods]"
  CFG="${SERVER_DIR}/server.cfg"
}

download_and_extract() {
  [[ -n "$URL" ]] || die "Give the direct download link."
  command -v unar >/dev/null 2>&1 && command -v file >/dev/null 2>&1 \
    || { log "Installing unpack tools"; apt-get update -y >/dev/null; apt-get install -y unar file >/dev/null; }

  rm -rf "$MOD_DIR"
  mkdir -p "$FILES"
  log "Downloading"
  curl -fL --retry 2 -A 'Mozilla/5.0' -e 'https://www.gta5-mods.com/' "$URL" -o "$MOD_DIR/download"

  case "$(file -b --mime-type "$MOD_DIR/download")" in
    text/html|text/plain)
      die "That link is a web page, not the mod file. On the mod's download page, right-click the
       'click here' / download link -> Copy link address, and use that link." ;;
  esac

  log "Unpacking"
  unar -q -f -o "$FILES" "$MOD_DIR/download" >/dev/null || die "Could not unpack the download."
  rm -f "$MOD_DIR/download"

  # Archives inside the archive (.zip/.rar/.7z and OpenIV .oiv packages)
  local nested n
  for _ in 1 2 3; do
    mapfile -t nested < <(find "$FILES" -type f \( -iname '*.zip' -o -iname '*.rar' -o -iname '*.7z' -o -iname '*.oiv' \))
    [[ ${#nested[@]} -eq 0 ]] && break
    for n in "${nested[@]}"; do
      if unar -q -f -o "${n%.*}_unpacked" "$n" >/dev/null; then rm -f "$n"; else warn "Could not unpack ${n#"$FILES"/}"; fi
    done
  done
  chown -R "${FIVEM_USER}:${FIVEM_USER}" "$STAGING"
}

warn_big_files() {
  local big
  big="$(find "$1" -type f -regextype posix-extended -iregex "$STREAM_EXT_REGEX" -size +16M -exec du -h {} + | sed "s|$1/||")"
  if [[ -n "$big" ]]; then
    warn "Files over 16 MB can cause missing textures or crashes for players with less video memory:"
    echo "$big"
  fi
}

# Car spawn names, read from any vehicles.meta
show_models() {
  local models
  models="$(find "$1" -type f -iname 'vehicles.meta' -exec grep -ohiP '<modelName>\s*\K[^<\s]+' {} + 2>/dev/null | sort -u | tr '\n' ' ' || true)"
  if [[ -n "$models" ]]; then echo "Car spawn names: $models"; fi
}

report() {
  [[ -d "$FILES" ]] || die "Nothing downloaded for '${NAME}' yet. Run inspect first."
  log "Files in '${NAME}'"
  (cd "$FILES" && find . -type f | sed 's|^\./||' | sort | head -n 300) || true
  local total; total="$(find "$FILES" -type f | wc -l)"
  [[ $total -gt 300 ]] && echo "... (${total} files, first 300 shown)"

  log "File types"
  find "$FILES" -type f | sed -n 's/.*\.\([^./]*\)$/\1/p' | tr '[:upper:]' '[:lower:]' | sort | uniq -c | sort -rn

  log "Summary"
  echo "FiveM resources inside: $(find "$FILES" \( -name fxmanifest.lua -o -name __resource.lua \) | wc -l)"
  echo "Streamable files:       $(find "$FILES" -type f -regextype posix-extended -iregex "$STREAM_EXT_REGEX" | wc -l)"
  echo "Needs a PC to convert:  $(find "$FILES" -type f \( -iname '*.rpf' -o -iname '*.oac' -o -iname '*.awc' \) | wc -l)  (.rpf/.oac/.awc)"
  show_models "$FILES"
  show_rpf_types "$FILES"
  warn_big_files "$FILES"
}

# Encryption of any .rpf archives (OPEN/none can be unpacked on Linux, AES/NG can't)
show_rpf_types() {
  local f enc
  while IFS= read -r -d '' f; do
    case "$(od -An -tx4 -j12 -N4 "$f" | tr -d ' ')" in
      4e45504f) enc="OPEN (unencrypted)" ;;
      00000000) enc="none (unencrypted)" ;;
      0ffffff9) enc="AES (encrypted)" ;;
      0fefffff) enc="NG (encrypted)" ;;
      *)        enc="unknown" ;;
    esac
    echo "RPF: ${f#"$FILES"/} -> ${enc}"
  done < <(find "$1" -type f -iname '*.rpf' -print0 | sort -z)
}

# New mods go ABOVE the vMenu block, so they start before vMenu (otherwise their
# cars and guns don't show up in vMenu). Without that block, add at the bottom.
add_ensure() {
  if grep -qxF "ensure $1" "$CFG"; then return; fi
  if grep -q '^# >>> vmenu-last' "$CFG"; then
    sed -i "/^# >>> vmenu-last/i ensure $1" "$CFG"
  else
    echo "ensure $1" >> "$CFG"
  fi
}

# Lists modded guns in vMenu's Weapon Options (cars are found by vMenu itself)
sync_vmenu() {
  if [[ -f "$(dirname "$0")/vmenu-sync.sh" ]]; then
    bash "$(dirname "$0")/vmenu-sync.sh" "$SERVER_DIR" || warn "Couldn't update vMenu's weapon list. Run: sudo bash vmenu-sync.sh"
  fi
}

# ----------------------------- actions ---------------------------------------
do_inspect() {
  download_and_extract
  report
  cat <<EOF

Nothing was installed. Paste this output to Claude, or install it with:
  sudo bash add-mod.sh install ${NAME}
EOF
}

do_install() {
  find_server_dir
  [[ -n "$URL" ]] && download_and_extract
  [[ -d "$FILES" ]] || die "Nothing downloaded for '${NAME}'. Give the download link."
  mkdir -p "$RES_ROOT" "$INSTALLED_DB"
  cp "$CFG" "$CFG.bak.$(date +%Y%m%d-%H%M%S)"

  local installed=() manifests m dir res
  mapfile -t manifests < <(find "$FILES" \( -name fxmanifest.lua -o -name __resource.lua \) | sort)

  if [[ ${#manifests[@]} -gt 0 ]]; then
    # ---- Mod already is a FiveM resource (or several) ----
    for m in "${manifests[@]}"; do
      if grep -qE '^\s*(client|server|shared)_scripts?\b' "$m" && [[ "$ALLOW_SCRIPTS" != "yes" ]]; then
        echo "---- $m ----"; cat "$m"
        die "This mod contains scripts. Have them checked, then re-run with --allow-scripts."
      fi
    done
    for m in "${manifests[@]}"; do
      dir="$(dirname "$m")"
      if [[ ${#manifests[@]} -eq 1 ]]; then
        res="$NAME"
      else
        res="${NAME}_$(basename "$dir" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_\n' '_')"
      fi
      rm -rf "${RES_ROOT:?}/$res"
      cp -r "$dir" "$RES_ROOT/$res"
      installed+=("$res")
    done
  else
    # ---- Loose single-player files: build a resource around them ----
    res="$NAME"
    rm -rf "${RES_ROOT:?}/$res"
    mkdir -p "$RES_ROOT/$res/stream"
    local f base count=0 has_map="no" has_ytyp="no"
    while IFS= read -r -d '' f; do
      base="$(basename "$f")"
      if [[ -e "$RES_ROOT/$res/stream/$base" ]]; then
        warn "Two files named $base - kept the first one."
        continue
      fi
      cp "$f" "$RES_ROOT/$res/stream/$base"
      count=$((count + 1))
      if [[ "${base,,}" == *.ymap ]]; then has_map="yes"; fi
      if [[ "${base,,}" == *.ytyp ]]; then has_map="yes"; has_ytyp="yes"; fi
    done < <(find "$FILES" -type f -regextype posix-extended -iregex "$STREAM_EXT_REGEX" -print0 | sort -z)

    # Car/weapon .meta files go in data/<source folder>/ with lowercase names
    local meta_count=0 rel d
    while IFS= read -r -d '' f; do
      rel="${f#"$FILES"/}"
      d="$(dirname "$rel" | tr -c 'A-Za-z0-9_\n' '_')"
      mkdir -p "$RES_ROOT/$res/data/$d"
      cp "$f" "$RES_ROOT/$res/data/$d/$(basename "$rel" | tr '[:upper:]' '[:lower:]')"
      meta_count=$((meta_count + 1))
    done < <(find "$FILES" -type f -iname '*.meta' -print0 | sort -z)

    if [[ $count -eq 0 ]]; then
      rm -rf "${RES_ROOT:?}/$res"
      report
      if [[ -n "$(find "$FILES" -type f -iname '*.rpf' -print -quit)" ]]; then
        die "This is a single-player DLC pack (dlc.rpf). FiveM can't load .rpf files. Look for a
       FiveM version of the mod, or paste the output above to Claude."
      fi
      die "No files FiveM can use directly. Paste the output above to Claude."
    fi

    local -A meta_types=(
      [handling.meta]=HANDLING_FILE
      [vehicles.meta]=VEHICLE_METADATA_FILE
      [carcols.meta]=CARCOLS_FILE
      [carvariations.meta]=VEHICLE_VARIATION_FILE
      [vehiclelayouts.meta]=VEHICLE_LAYOUTS_FILE
      [weapons.meta]=WEAPONINFO_FILE
      [weaponarchetypes.meta]=WEAPON_METADATA_FILE
      [weaponanimations.meta]=WEAPON_ANIMATIONS_FILE
      [weaponcomponents.meta]=WEAPONCOMPONENTSINFO_FILE
      [pedpersonality.meta]=PED_PERSONALITY_FILE
    )
    local k
    {
      echo "-- Built by add-mod.sh from a single-player mod"
      echo "fx_version 'cerulean'"
      echo "game 'gta5'"
      if [[ $has_map == "yes" ]]; then echo "this_is_a_map 'yes'"; fi
      if [[ $has_ytyp == "yes" ]]; then echo "data_file 'DLC_ITYP_REQUEST' 'stream/*.ytyp'"; fi
      if [[ $meta_count -gt 0 ]]; then
        echo "files { 'data/**/*.meta' }"
        for k in "${!meta_types[@]}"; do
          if [[ -n "$(find "$RES_ROOT/$res/data" -name "$k" -print -quit)" ]]; then
            echo "data_file '${meta_types[$k]}' 'data/**/$k'"
          fi
        done
      fi
    } > "$RES_ROOT/$res/fxmanifest.lua"
    echo "Copied ${count} files into stream/ and ${meta_count} .meta files into data/"
    warn_big_files "$RES_ROOT/$res/stream"

    local skipped
    skipped="$(find "$FILES" -type f -regextype posix-extended -not -iregex "$STREAM_EXT_REGEX" \
      -not -iregex '.*\.(meta|txt|md|rtf|pdf|doc|docx|jpg|jpeg|png|gif|bmp|url|html?|xml)$' | sed "s|^$FILES/||")"
    if [[ -n "$skipped" ]]; then
      warn "These files were skipped (FiveM can't use them as-is):"
      echo "$skipped" | head -n 50 || true
    fi
  fi

  for res in "${installed[@]:-$NAME}"; do add_ensure "$res"; done
  printf '%s\n' "${installed[@]:-$NAME}" > "$INSTALLED_DB/$NAME"
  chown -R "${FIVEM_USER}:${FIVEM_USER}" "$RES_ROOT" "$CFG" "$STAGING"

  log "Installed: ${installed[*]:-$NAME}"
  for res in "${installed[@]:-$NAME}"; do show_models "$RES_ROOT/$res"; done
  sync_vmenu
  echo "Admins will find modded cars in vMenu > Vehicle Spawner (under their normal class, like Sports), and modded guns in Weapon Options > Custom Weapons."
  echo "Restart the server to load it:  txAdmin -> Restart  (or: sudo systemctl restart fivem)"
}

do_remove() {
  find_server_dir
  [[ -f "$INSTALLED_DB/$NAME" ]] || die "No installed mod called '${NAME}'."
  local res
  while IFS= read -r res; do
    [[ "$res" =~ ^[a-z0-9_]+$ ]] || continue
    rm -rf "${RES_ROOT:?}/$res"
    sed -i "/^ensure ${res}\s*$/d" "$CFG"
    echo "Removed $res"
  done < "$INSTALLED_DB/$NAME"
  rm -f "$INSTALLED_DB/$NAME"
  sync_vmenu
  echo "Restart the server to finish:  sudo systemctl restart fivem"
}

case "$ACTION" in
  inspect) do_inspect ;;
  install) do_install ;;
  remove)  do_remove ;;
  *)       usage ;;
esac
