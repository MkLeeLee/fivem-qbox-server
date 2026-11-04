# Your New Zealand Mods

Every mod goes through [add-mod.sh](add-mod.sh), which downloads it **straight onto the server**,
unpacks it there and turns it into a FiveM resource in `resources/[mods]/`.
Nothing is downloaded to your PC, and nothing inside a mod is ever run.

## Before running any command below

`add-mod.sh` is already on the server from the GitHub download. Go to its folder and grab the newest version:

```bash
cd ~/fivem-qbox-server && git pull
```

## How to get a mod's direct link (without downloading it)

gta5-mods.com hides the real file behind a download page:

1. Open the mod's **download page** (the links below).
2. The site counts down and then **starts the download by itself. Cancel it** in your browser (or close the tab once you have the link).
3. Right-click the **"click here"** / download link → **Copy link address**. It usually starts with `https://files.gta5-mods.com/...`
4. Paste it into the command, **inside quotes**.

---

## Status of your 6 mods

| # | Mod | Works on FiveM? | What to do |
|---|---|---|---|
| 1 | Forests of San Andreas Revised | ✅ Has a FiveM server version | Install |
| 2 | NZ flags at Mission Row PD | ✅ Has FiveM instructions | Install |
| 3 | NZ Police uniform + tattoos | ⚠️ Probably, it's a 2015 single-player mod | Inspect first |
| 4 | Interiors & Props (New Zealand) | ⚠️ Probably, it's a 2015 single-player mod | Inspect first |
| 5 | NZ Police car skin | ⚠️ Base car found (LSPD Jackal) | Inspect both, see below |
| 6 | NZ Police siren | ❌ Not as-is | Use a FiveM siren instead |

### 1. Forests of San Andreas Revised ✅

Use version **5.7-FiveM-Server**, the newest FiveM build. (6.0 is single-player only.)
Download page: <https://www.gta5-mods.com/maps/forests-of-san-andreas-revised/download/182443>

```bash
sudo bash add-mod.sh install forests "PASTE_DIRECT_LINK_HERE"
```

Adds about 13,000 trees and bushes across the map. Each friend downloads around 57 MB the first time they join.

### 2. NZ flags at Mission Row PD ✅

Download page: <https://www.gta5-mods.com/maps/new-zealand-flags-at-missionrow-police-department/download/95168>

```bash
sudo bash add-mod.sh install nz_flags "PASTE_DIRECT_LINK_HERE"
```

The author (charlie girl) asks for credit, for example on your Discord or loading screen.

### 3. NZ Police uniform + tattoos ⚠️

Download page: <https://www.gta5-mods.com/player/new-zealand-police-uniform-tattoos/download/3842>

This mod **replaces** existing GTA clothing pieces instead of adding new ones, and its page
doesn't say which ones. Inspect it first:

```bash
sudo bash add-mod.sh inspect nz_uniform "PASTE_DIRECT_LINK_HERE"
```

**Paste the output to me.** I'll check which clothing it replaces and rename the files so FiveM loads them.
They may need to be renamed to FiveM's naming for player clothing.

### 4. Interiors & Props (New Zealand) ⚠️

Download page: <https://www.gta5-mods.com/misc/interiors-props-new-zealand/download/22903>

It replaces textures on ATMs (ANZ, Westpac), phone boxes, bus stops, vending machines, flags and more.
Texture swaps like these usually work on FiveM, but I want to see the files first:

```bash
sudo bash add-mod.sh inspect nz_props "PASTE_DIRECT_LINK_HERE"
```

**Paste the output to me.** If it all looks streamable, you'll just run `sudo bash add-mod.sh install nz_props`.
The ATMs keep working with the bank system because only their textures change.

### 5. NZ Police car (LSPD Jackal + NZ skin) ⚠️ Inspect first

The skin needs the **LSPD Jackal** car by Kirigaya, which is still on gta5-mods (2015, 11.5 MB). It's a
**replace** car made of plain model and texture files (`.yft`/`.ytd`), the kind FiveM can stream. The plan is to
combine the car and the NZ skin into one resource that **replaces `police3`**, the Police Interceptor in GTA.
The police garage's `police3` then becomes the NZ Jackal.

- Car: <https://www.gta5-mods.com/vehicles/lspd-jackel/download/19848>
- Skin: <https://www.gta5-mods.com/paintjobs/new-zealand-police-car-skin-v1/download/5660>

```bash
sudo bash add-mod.sh inspect nzjackal "PASTE_CAR_DIRECT_LINK_HERE"
```
```bash
sudo bash add-mod.sh inspect nzskin "PASTE_SKIN_DIRECT_LINK_HERE"
```

**Paste me both outputs.** The files need renaming to `police3` and the skin's texture swapped in. I'll give you the
exact commands, since that depends on the file names inside.

Notes: the car's author doesn't allow re-uploading it, so keep it on your server only and credit Kirigaya and MattJeter.
(With `no_npc_services` on, NPC police won't spawn, so only players drive it.) Some commenters reported handling issues and crashes in
single player, so we'll test it on its own first.

### 6. NZ Police siren ❌

This mod edits the game's built-in sound archive (`vehicles.awc`) with OpenIV on a PC. A FiveM server
can't push that file to players this way. Commenters also say the included file is outdated and won't import.

**Alternative:** look for an NZ siren made for FiveM. Searching "NZ police siren FiveM" or "server side sirens" on
the cfx.re forum or gta5-mods works well. Send me the link and I'll set it up.

---

## Guns

### 7. Colt 1911 ✅ (replaces the Combat Pistol)

Download page: <https://www.gta5-mods.com/weapons/colt-1911/download/198584>

This swaps the look of the game's **Combat Pistol** (`WEAPON_COMBATPISTOL`). The gun already exists in
Qbox and ox_inventory, so no new weapon code is needed. Every Combat Pistol in the game turns into the
Colt, including ones police NPCs and the police armory hand out.

**Step 1: check what's inside** (71 MB is large for a pistol, so it may include an HQ and a normal version):

```bash
sudo bash add-mod.sh inspect colt1911 "PASTE_DIRECT_LINK_HERE"
```

- If you see **one set** of files (`w_pi_combatpistol.ydr`, `w_pi_combatpistol.ytd`, plus maybe `..._mag1`/`..._mag2`) and no large-file warning, install it:
  ```bash
  sudo bash add-mod.sh install colt1911
  ```
- If you see **two sets** in different folders, or a "files over 16 MB" warning, **paste me the output** and I'll pick the right one.

**Step 2: rename it and sell it in the gun store.** Edit in txAdmin → CFG Editor, or over SSH.

In `resources/[ox]/ox_inventory/data/weapons.lua`, find the `WEAPON_COMBATPISTOL` line and change its label:

```lua
['WEAPON_COMBATPISTOL'] = { label = 'Colt 1911', weight = 1100, durability = 0.2, ammoname = 'ammo-45' },
```

Only change `label` if you like. Here the weight is also more realistic, and `ammoname = 'ammo-45'` makes it use .45 ammo instead of 9 mm.
(How hard it hits in game stays the same.)

In `resources/[ox]/ox_inventory/data/shops.lua`, add it to the **Ammunation** `inventory` list:

```lua
{ name = 'WEAPON_COMBATPISTOL', price = 4500, license = 'weapon' },
{ name = 'ammo-45', price = 8 },
```

If either line is already there, just change the price.

**Step 3: restart** (txAdmin → Restart). Test with `/giveitem [your id] WEAPON_COMBATPISTOL 1`.

---

## Cars

All three cars are by **SilentM Customs**. The Rebla page allows FiveM servers to use it **with credit to SilentM Customs**.
Put a credit line on your Discord or loading screen.

**Inspect each car first.** These downloads often contain **both** a single-player version (a `dlc.rpf`, which FiveM
can't load) and a FiveM version. `add-mod.sh` picks the FiveM one automatically. If there's only a `dlc.rpf`, the
script tells you, and that car needs a FiveM version instead.

| # | Car | Download page | Command name |
|---|---|---|---|
| 8 | Rebla GTS Custom | <https://www.gta5-mods.com/vehicles/rebla-gts-custom-add-on-tuning-template/download/203283> | `reblac` |
| 9 | Elegy Zirconium Body Kit V2 | <https://www.gta5-mods.com/vehicles/elegy-zirconium-body-kit-v2-add-on-fivem/download/173011> | `elegyz2` |
| 10 | Buffalo STX Hellfire (use **1.1**) | <https://www.gta5-mods.com/vehicles/buffalo-stx-hellfire-custom-add-on-fivem/download/170253> | `buffalowb` |

```bash
sudo bash add-mod.sh inspect reblac "PASTE_DIRECT_LINK_HERE"
```
```bash
sudo bash add-mod.sh inspect elegyz2 "PASTE_DIRECT_LINK_HERE"
```
```bash
sudo bash add-mod.sh inspect buffalowb "PASTE_DIRECT_LINK_HERE"
```

**Paste me the three outputs.** Each one ends with a line like `Car spawn names: ...`. If they look good, install them:

```bash
sudo bash add-mod.sh install reblac
```

(and the same with `elegyz2` and `buffalowb`).

**Sell them at the dealership.** Add one entry per car to `resources/[qbx]/qbx_core/shared/vehicles.lua`,
just above the very last `}` in the file. **Replace the spawn names with the ones the script printed.**
The ones below are guesses based on the folder names.

```lua
    reblac = {
        name = 'Rebla GTS Custom',
        brand = 'Ubermacht',
        model = 'reblac',
        price = 185000,
        category = 'suvs',
        type = 'automobile',
        hash = `reblac`,
    },
    elegyz2 = {
        name = 'Elegy Zirconium',
        brand = 'Annis',
        model = 'elegyz2',
        price = 240000,
        category = 'sports',
        type = 'automobile',
        hash = `elegyz2`,
    },
    buffalowb = {
        name = 'Buffalo STX Hellfire',
        brand = 'Bravado',
        model = 'buffalowb',
        price = 210000,
        category = 'muscle',
        type = 'automobile',
        hash = `buffalowb`,
    },
```

The category decides where it's sold: `sports`, `muscle` and `suvs` all show up at **PDM**.
Change the prices to fit your economy (players start with $5,500 total by default).
To test before buying: vMenu → Vehicle Spawner → Spawn by name (admins only).

**Notes:**
- These cars are based on GTA Online vehicles (Buffalo STX, Elegy Retro, Rebla GTS). Make sure `server.cfg` has
  `sv_enforceGameBuild` set to **2545 or higher**. The Qbox recipe already sets a recent build, so this should be fine.
- All three have nitro, which comes from the car's handling and may or may not work on FiveM. Known bug from the author: some widebody clipping.
- The Elegy is 119 MB, so watch for the "files over 16 MB" warning. Big cars mean a longer first join for your friends.

### Real-brand cars (YCA): heads-up first

All three of these were **converted from Forza** (Forza Horizon 3 / Forza Motorsport 4). Cfx.re's rules for FiveM
don't allow models ripped from other games, so a server using them can be taken down. On a private, unlisted
friends server the chance of that is small, but it's your call. Lore-friendly cars made for GTA, like the
SilentM ones above, are the safe choice.

| # | Car | Type | Download page |
|---|---|---|---|
| 15 | Nissan GT-R 2017 (1.0) | Add-on, single-player DLC pack | <https://www.gta5-mods.com/vehicles/2015-nissan-gtr-nismo-yca-y97y/download/31526> |
| 16 | Mercedes-AMG GT R 2017 | **Replaces the Feltzer** | <https://www.gta5-mods.com/vehicles/mercedes-benz-amg-gt-r-2017/download/64515> |
| 17 | Nissan Skyline R34 | Add-on, single-player DLC pack (2015) | <https://www.gta5-mods.com/vehicles/nissan-skyline-gt-r-bnr34-yca-y97y/download/14749> |

**Mercedes (replace):** this is probably loose files, which `add-mod.sh` can handle:

```bash
sudo bash add-mod.sh inspect amggtr "PASTE_DIRECT_LINK_HERE"
```

Every **Feltzer** in the game (traffic, and the one PDM sells) becomes the AMG GT R. Its existing `feltzer2` entry
in `qbx_core/shared/vehicles.lua` is where you change the name to "Mercedes-AMG GT R" and set the price.

**GT-R and Skyline (single-player DLC packs):** they come as a `dlc.rpf` with no FiveM version, and FiveM can't
load `.rpf` files. Run inspect anyway:

```bash
sudo bash add-mod.sh inspect gtr "PASTE_DIRECT_LINK_HERE"
```
```bash
sudo bash add-mod.sh inspect skyline "PASTE_DIRECT_LINK_HERE"
```

Look for the `RPF: ... ->` line in the output:
- **OPEN** or **none**: the archive isn't encrypted. I can write a converter that unpacks it on the server.
- **AES** or **NG**: it's encrypted and can only be unpacked on a PC with OpenIV or CodeWalker. Skip it, or find a FiveM version.

Paste me the outputs and I'll tell you what's possible.

---

## Things you don't need (single-player only)

These are **single-player** scripts and PC tools. FiveM blocks single-player scripts (ScriptHookV), and the
server already does each job:

| Link | Why you don't need it |
|---|---|
| Open All Interiors | **bob74_ipl** (already installed) loads the online interiors |
| Add-On Vehicle Spawner | **vMenu** → Vehicle Spawner (admins). Modded cars appear there on their own (under their normal class), and modded guns under Weapon Options → Custom Weapons |
| Map Editor | Single-player map maker. Maps on FiveM come as ymap files, which `add-mod.sh` handles |
| Fuel Script V | **ox_fuel** is already installed (gas stations, jerry cans) |
| CodeWalker | A Windows PC tool for building and converting maps and cars. It runs on your PC, not the server, so skip it since you don't want downloads on your computer |

---

## Maps (MLOs)

All three include a FiveM version, so they should install directly. If the script says
"This mod contains scripts", paste me the output and I'll check it.

### 11. Car Dealer (Patoche) ✅

Download page (**2.0.1**): <https://www.gta5-mods.com/maps/car-dealer-fivem-sp-ready/download/143393>

```bash
sudo bash add-mod.sh install cardealer "PASTE_DIRECT_LINK_HERE"
```

This is just the **building**. Want it to be a real working dealership for your custom cars? Go there in game, turn on
vMenu → Misc Settings → **Show Coordinates**, and send me the coordinates of:
1. the showroom floor where display cars should sit,
2. the spot outside where bought cars should spawn.

I'll write a second shop for `qbx_vehicleshop` so your custom cars are sold there instead of at PDM.

### 12. Irish Pub (CC-Customs) ✅

Download page (**v1.1**, the newer one even though the site labels v1.0 as current): <https://www.gta5-mods.com/maps/mlo-irish-pub-fivem-altv-sp/download/109387>

```bash
sudo bash add-mod.sh install irishpub "PASTE_DIRECT_LINK_HERE"
```

The download has FiveM, AltV and single-player folders, and the script uses the FiveM one. The author doesn't allow re-uploading it.
One server reported voice chat not working inside, so tell me if that happens.

### 13. GTA IV Burger Shot interior (Smallo) ✅

Use **v2.0 (Legacy)**, not v2.1. v2.1 is for GTA V *Enhanced* single player, and FiveM runs on the normal (Legacy) game.
Download page: <https://www.gta5-mods.com/maps/gtaiv-burgershot-interior-sp-and-fivem/download/95624>

```bash
sudo bash add-mod.sh install burgershot "PASTE_DIRECT_LINK_HERE"
```

This replaces the inside of the Vespucci Burger Shot. If anyone crashes near it, tell me. There's a known fix
(removing two map files), and I'll give you the exact command.

### 14. Small Hideout (zaquu_mlo) ✅

Download page (**V1**): <https://www.gta5-mods.com/maps/mlo-small-hideout-add-on-sp-fivem/download/195462>

```bash
sudo bash add-mod.sh install hideout "PASTE_DIRECT_LINK_HERE"
```

A small add-on interior in **Del Perro** (26.7 MB). The author says it works on FiveM as-is.

**Want to use it as your crew's base?** Go inside, turn on vMenu → Misc Settings → **Show Coordinates**, and send me
the coordinates where you want a shared **stash** (storage everyone in the crew can use). I'll add it with ox_inventory.
It can't be a buyable house, because qbx_properties houses use their own built-in interiors and can't use a map like this.

---

## Managing mods later

```bash
sudo bash add-mod.sh remove nz_flags
```

- Installed mods are listed in `server.cfg` as `ensure <name>` lines.
- After any install or remove, **restart the server** (txAdmin → Restart).
- A mod that contains scripts won't install until it's been checked. Send me the output and I'll review it.
