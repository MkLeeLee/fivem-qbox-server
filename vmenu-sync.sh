#!/usr/bin/env bash
# =============================================================================
#  Lists your modded guns in vMenu's Weapon Options menu.
#
#  vMenu can't ask the game which weapons exist, so it reads them from
#  config/weapons.json. This script finds every add-on weapon in your
#  resources/[custom] and resources/[mods] folders (from their weapons.meta
#  files) and puts them in a "Custom Weapons" group there.
#
#  Modded CARS need nothing: vMenu finds them on its own, as long as they start
#  before vMenu does (post-install.sh and add-mod.sh take care of that).
#
#  add-mod.sh and post-install.sh run this for you. To run it by hand:
#    sudo bash vmenu-sync.sh [/path/to/server/folder]
#  Then restart the server (or: restart vMenu.Enhanced).
# =============================================================================
set -euo pipefail

FIVEM_HOME="/home/fivem"
SERVER_DIR="${1:-}"
if [[ -z "$SERVER_DIR" ]]; then
  mapfile -t CANDIDATES < <(find "$FIVEM_HOME" -maxdepth 4 -name server.cfg \
    -not -path '*/fxserver/*' -not -path '*/mod-staging/*' -printf '%h\n')
  [[ ${#CANDIDATES[@]} -eq 1 ]] || { echo "ERROR: expected one server.cfg under $FIVEM_HOME, found ${#CANDIDATES[@]}. Pass the server folder as an argument." >&2; exit 1; }
  SERVER_DIR="${CANDIDATES[0]}"
fi

WEAPONS_JSON="$SERVER_DIR/resources/[custom]/vMenu.Enhanced/config/weapons.json"
if [[ ! -f "$WEAPONS_JSON" ]]; then
  echo "vMenu Enhanced isn't installed yet ($WEAPONS_JSON missing). Run post-install.sh first." >&2
  exit 1
fi

python3 - "$WEAPONS_JSON" "$SERVER_DIR/resources/[custom]" "$SERVER_DIR/resources/[mods]" <<'PY'
import json, os, re, shutil, sys
import xml.etree.ElementTree as ET

weapons_json, *roots = sys.argv[1:]
GROUP = "Custom Weapons"


def strip_comments(text):
    """weapons.json allows // and /* */ comments. Remove them (outside strings)."""
    out, i, n, in_str = [], 0, len(text), False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(text[i + 1]); i += 1
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str = True; out.append(c)
        elif text.startswith("//", i):
            while i < n and text[i] != "\n":
                i += 1
            continue
        elif text.startswith("/*", i):
            j = text.find("*/", i + 2)
            i = n if j < 0 else j + 2
            continue
        else:
            out.append(c)
        i += 1
    return re.sub(r",(\s*[}\]])", r"\1", "".join(out))  # tolerate trailing commas


raw = open(weapons_json, encoding="utf-8").read()
data = json.loads(strip_comments(raw))

# Keep the original, with vMenu's comments, the first time we rewrite the file
backup = weapons_json + ".orig"
if not os.path.exists(backup):
    shutil.copyfile(weapons_json, backup)

old_labels = {k.lower(): v for k, v in data.pop(GROUP, {}).items()}  # keep names you edited
known = {name.lower() for group in data.values() for name in group}

found = {}
for root in roots:
    for dirpath, dirs, files in os.walk(root):
        # vMenu itself ships no add-on weapons
        dirs[:] = [d for d in dirs if d != "vMenu.Enhanced"]
        for f in files:
            if f.lower() != "weapons.meta":
                continue
            path = os.path.join(dirpath, f)
            try:
                tree = ET.parse(path)
            except ET.ParseError as e:
                print(f"  skipped {path}: {e}")
                continue
            for item in tree.iter("Item"):
                if item.get("type") != "CWeaponInfo":
                    continue
                name = (item.findtext("Name") or "").strip()
                if not re.fullmatch(r"WEAPON_[A-Za-z0-9_]+", name):
                    continue
                key = name.lower()
                if key in known or key in found:
                    continue  # already in a vMenu group (e.g. a mod that replaces the Combat Pistol)
                label = " ".join(w.capitalize() for w in key[len("weapon_"):].split("_"))
                found[key] = old_labels.get(key, label)

if found:
    data[GROUP] = dict(sorted(found.items()))

with open(weapons_json, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")

if found:
    print(f"vMenu Weapon Options: {len(found)} modded gun(s) listed under '{GROUP}':")
    for k, v in sorted(found.items()):
        print(f"  {k}  ->  {v}")
    print("Rename any of them by editing the text after the arrow in config/weapons.json.")
else:
    print("No add-on weapons found, so vMenu's Weapon Options is unchanged.")
PY

chown -R fivem:fivem "$SERVER_DIR/resources/[custom]/vMenu.Enhanced/config" 2>/dev/null || true
