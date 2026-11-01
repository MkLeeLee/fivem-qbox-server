# Qbox FiveM Server on Linux (txAdmin + vMenu): Setup Guide

Everything installs **on the Linux server**. Your Windows PC needs nothing new:
Windows 11 already includes `ssh`, and you only need a web browser for txAdmin.

## What you get

| You asked for | What provides it |
|---|---|
| Framework | **Qbox** (`qbx_core`), from txAdmin's built-in "QBox Framework" recipe |
| Panel | **txAdmin** (web panel on port 40120) |
| Inventory | **ox_inventory** (press TAB in game) |
| Money system | `qbx_core` cash/bank + **Renewed-Banking** (ATMs/banks) |
| Economy | Paychecks, jobs (trucker, garbage, taxi, bus, tow, mechanic...), shops, vehicle shop |
| Houses to buy | **qbx_properties** (a realtor creates houses, players buy or rent them) |
| Custom cars | `custom_vehicles` resource + `qbx_vehicleshop` |
| Custom guns | `custom_weapons` resource + ox_inventory gun shop |
| vMenu | **vMenu**, locked down so it can't hand out free cars, guns or money |

The recipe also includes garages, vehicle keys, fuel, clothing (illenium-appearance),
a phone (npwd), police/EMS, robberies and drugs. You can remove any of them later.

## What you need

- **A Linux VPS or PC** running **Ubuntu 24.04** (22.04 and Debian 12 also work).
  For a small friends server, aim for **4 CPU cores, 8 GB RAM, 40+ GB SSD**.
- **A free Cfx.re server license key**: sign in at <https://portal.cfx.re> → Server Registration Keys → New. Use your server's IP.
- The server's **IP address** and **root password or SSH key** (from your VPS provider).

---

## Step 1: Connect to the server

Open **PowerShell** or **Terminal** on Windows:

```bash
ssh root@YOUR_SERVER_IP
```

## Step 2: Run the installer

On the server, download these scripts from GitHub and run the installer:

```bash
sudo apt update && sudo apt install -y git
git clone https://github.com/MkLeeLee/fivem-qbox-server.git
cd fivem-qbox-server
sudo bash install.sh
```

This takes 2 to 5 minutes. It installs MariaDB (the database Qbox needs), creates a
database, downloads the FiveM Linux server and starts txAdmin as a service that also
starts automatically on reboot. **At the end it prints your database password and the txAdmin PIN. Keep that window open.**

## Step 3: Set up txAdmin

1. In your browser, open `http://YOUR_SERVER_IP:40120`
2. Enter the **PIN** the installer showed. If you missed it:
   ```bash
   journalctl -u fivem -n 80 --no-pager
   ```
3. Sign in with your Cfx.re account and create an admin password.
4. In the setup wizard:
   - Server name: anything you like
   - Deployment type: **Popular Recipes** → **QBox Framework**
   - Paste your **license key** from portal.cfx.re
   - Database: `localhost`, port `3306`, username `qbox`, plus the **password the installer printed**. Database name: `qbox` (or keep the suggested `qbox_xxxx`, which also works).
5. Let it deploy (a few minutes). On the last screen, keep the server.cfg as it is and click **Save & Run Server**.

## Step 4: Add vMenu and the custom car/gun folders

Back in the SSH window:

```bash
cd ~/fivem-qbox-server
sudo bash post-install.sh
```

This downloads vMenu, writes `vmenu_permissions.cfg`, creates the `custom_vehicles`
and `custom_weapons` resources, adds the settings to `server.cfg` and restarts the server.

It also adds **`no_npc_services`**, which removes all NPC police, EMS and fire: no cops in traffic, no
parked police cars or ambulances at stations, no dispatch when you commit crimes, and no wanted stars.
Friends who take the police or EMS job still work normally, with their job cars.
To bring NPCs back, put a `#` in front of `ensure no_npc_services` in server.cfg and restart.
To change which models are blocked, edit `resources/[custom]/no_npc_services/config.lua`.

It also installs **`glow_hud`**, the glowing HUD, and moves Qbox's `qbx_hud` to `disabled-resources/`:

- **Always:** location at the top, armor and health bars under the map, hunger, thirst, stress and stamina, and a voice meter
- **In cars:** speed, RPM (inner ring), fuel (outer ring), and FUEL, ENG, SEAT and LIGHT indicators
- **In planes and helicopters:** speed and altitude tapes, artificial horizon, height above ground, and gear and engine indicators

Settings such as MPH or KM/H are in `resources/[custom]/glow_hud/config.lua`. The HUD also takes over
stress and the `/cash` and `/bank` commands from `qbx_hud`. `qbx_hud`'s settings menu is gone.

## Step 5: Make yourself admin and keep it friends-only

1. Join the server once (Step 6), then in txAdmin go to **Players** → click your name → copy your `fivem:` or `license:` identifier.
2. In txAdmin, open **CFG Editor**, find the `add_principal` lines Qbox already uses for admins, and add yours if it's missing:
   ```
   add_principal identifier.fivem:1234567 group.admin
   ```
   That gives you Qbox admin (`/admin`) **and** full vMenu.
3. **Whitelist**: txAdmin → **Settings** → **Player Manager** → Whitelist Mode → **Approved License**.
   When a friend tries to join the first time, approve them under **Whitelist** in txAdmin.
4. The server is already hidden from the public server list (`sv_master1 ""`).

## Step 6: Join

In FiveM press **F8** and type:

```
connect YOUR_SERVER_IP:30120
```

| Key | What it does |
|---|---|
| **M** | vMenu |
| **TAB** | Inventory |
| **F1** | Radial menu (Qbox) |
| **Alt** (hold) | ox_target, to interact with things |

---

## Customizing the economy

Edit files in txAdmin → **CFG Editor**, or over SSH. Your server folder is
`/home/fivem/txData/<YourServerName>.base/`. Restart the server after changes.

| What | File (inside `resources/`) | Setting |
|---|---|---|
| Starting money | `[qbx]/qbx_core/config/server.lua` | `money.moneyTypes = { cash = 500, bank = 5000, crypto = 0 }` |
| How often paychecks come | same file | `paycheckTimeout = 10` (minutes) |
| Who pays the paycheck | same file | `paycheckSociety = false` (true = paid from the job's company account) |
| Pay per job/rank | `[qbx]/qbx_core/shared/jobs.lua` | `payment = ...` on each grade |
| Car prices | `[qbx]/qbx_core/shared/vehicles.lua` | `price` on each car |
| Shop and gun-store prices | `[ox]/ox_inventory/data/shops.lua` | `price` on each item |
| Item weights | `[ox]/ox_inventory/data/items.lua` | `weight` |

For friends to earn money: the trucker, garbage, taxi, bus, tow, recycle, vineyard and
diving jobs are already installed. Get them at City Hall, which is on the map.

Admin money commands (in chat): `/givemoney [id] cash 10000` and `/setmoney [id] bank 50000`.

## Houses you can buy (qbx_properties)

Houses are created in game by someone with the **realestate** job:

1. Give yourself the job: `/setjob [your id] realestate 0`
2. Stand at a house door and type `/createproperty`. Choose the interior, price and (optionally) a garage spot.
3. Friends walk up to the door and buy or rent it. Their house gets storage (stash) and a wardrobe.

Set your job back with `/setjob [id] unemployed 0` when you're done.

## Adding mods from gta5-mods.com (maps, props, textures)

Use [add-mod.sh](add-mod.sh). It downloads, unpacks and converts mods on the server.
See [MODS.md](MODS.md) for how it works and for the status of your New Zealand mods.

## Adding custom cars

Most car downloads already come as a FiveM resource (a folder with `fxmanifest.lua`).
**If yours does**, upload the whole folder into `resources/[custom]/` and add
`ensure foldername` to `server.cfg`.

**If it's loose files**, use the ready-made `custom_vehicles` resource:

```
resources/[custom]/custom_vehicles/
├── stream/mycar/   ← mycar.yft, mycar_hi.yft, mycar.ytd ...
└── data/mycar/     ← vehicles.meta, handling.meta, carvariations.meta, carcols.meta
```

**Uploading without downloading to your PC:** download straight onto the server:

```bash
cd "/home/fivem/txData/YourServer.base/resources/[custom]"
sudo -u fivem wget "DIRECT_DOWNLOAD_LINK" -O mycar.zip
sudo -u fivem unzip mycar.zip
```

**Make it buyable**: in `[qbx]/qbx_core/shared/vehicles.lua`, copy an existing car's
entry, then change the model name (the spawn name from `vehicles.meta`), the
display name, the price and the category. The category decides which dealership
sells it (e.g. `sports` shows up at PDM). It then works with garages and keys.

Admins can also test-spawn it with vMenu → Vehicle Spawner → "Spawn by name".

## Adding custom guns

**Replacing how an existing gun looks** (easiest): put the `.ydr`/`.ytd` files in
`custom_weapons/stream/`. Nothing else is needed.

**A new add-on gun:**

1. Put its models in `custom_weapons/stream/` and its `.meta` files in `custom_weapons/meta/`
   (or upload the pack as its own resource if it has an `fxmanifest.lua`).
2. Register it in **ox_inventory** so it can sit in your inventory. In `[ox]/ox_inventory/data/weapons.lua`, under `Weapons = {`, add:
   ```lua
   ['WEAPON_MYGUN'] = { label = 'My Gun', weight = 1200, durability = 0.1, ammoname = 'ammo-9' },
   ```
3. Add a picture named `WEAPON_MYGUN.png` to `[ox]/ox_inventory/web/images/`.
4. Sell it: in `[ox]/ox_inventory/data/shops.lua`, add it to the Ammunation inventory:
   ```lua
   { name = 'WEAPON_MYGUN', price = 7500, license = 'weapon' },
   ```
   Remove `license = 'weapon'` if you don't want friends to need a gun license.
5. Give one to test: `/giveitem [id] WEAPON_MYGUN 1`

Only use cars and guns you're allowed to use, such as free releases or ones you bought.

## vMenu and Qbox: what's allowed and why

vMenu was built for freeroam servers. Several of its menus skip Qbox's systems:

| vMenu menu | Problem on Qbox | Who gets it |
|---|---|---|
| Vehicle Spawner | Free cars with no keys, skipping the dealership | Admins |
| Weapon Options | Guns that aren't in ox_inventory (they get removed or bug out) | Admins |
| Player Appearance | Fights with illenium-appearance and breaks saved outfits | Admins (avoid it) |
| Time / Weather | Fights with Renewed-Weathersync (vMenu sync is turned off) | Admins |
| Vehicle / Player Options | Free repairs, god mode | Admins (or everyone, see below) |
| Misc Settings | Harmless (speedometer, coordinates, keybinds...) | Everyone |

Want it more chill? Open `vmenu_permissions.cfg` and remove the `#` in front of the
**"fun mode"** lines to give everyone vehicle and player options and noclip.

## Everyday commands (over SSH)

```bash
sudo systemctl restart fivem
```
```bash
sudo journalctl -u fivem -f
```
```bash
cd ~/fivem-qbox-server && git pull && sudo bash install.sh
```
- **Restart** the server (or use the txAdmin dashboard).
- **Live log**: watch it with the second command, `Ctrl+C` to stop.
- **Update FiveM**: run `install.sh` again (your server and database are kept).

**Back up the database** (do this before big changes):

```bash
sudo mariadb-dump qbox > ~/qbox-backup-$(date +%F).sql
```

txAdmin can also schedule daily restarts: **Settings** → **Restarter**.

## Troubleshooting

| Problem | Fix |
|---|---|
| Can't open txAdmin page | Your VPS provider's firewall must allow TCP **40120** and TCP+UDP **30120** |
| Friends can't connect | Same ports. Also check the whitelist in txAdmin |
| "Couldn't load resource vMenu" | Run `sudo bash post-install.sh` again |
| An error mentions `custom_vehicles` or `custom_weapons` while they're empty | Put `#` in front of their `ensure` lines in server.cfg until you add something |
| Database errors during the recipe | Check the password in `/root/fivem-db-credentials.txt` |
| "Script won't run" after pasting | Run `sed -i 's/\r$//' install.sh` and try again |

**Security tip:** txAdmin's port 40120 is open to the internet. Use a strong password,
or limit it to your own IP: `sudo ufw allow from YOUR_HOME_IP to any port 40120`
(then remove the general 40120 rule).
