# FiveM Qbox Server (Linux + txAdmin)

Scripts and guides for a private Qbox roleplay server on Linux, for me and my friends.

**Includes:** Qbox framework · txAdmin · ox_inventory · cash/bank money with Renewed-Banking · jobs and paychecks ·
buyable houses (qbx_properties) · vMenu (locked down for admins) · custom cars and guns · no NPC police/EMS/fire

## Quick start (on a fresh Ubuntu 24.04 server)

```bash
sudo apt update && sudo apt install -y git
git clone https://github.com/MkLeeLee/fivem-qbox-server.git
cd fivem-qbox-server
sudo bash install.sh
```

Then follow **[GUIDE.md](GUIDE.md)** from Step 3 (txAdmin setup).

## Files

| File | What it does |
|---|---|
| [GUIDE.md](GUIDE.md) | Full step-by-step setup, economy, houses, cars, guns, troubleshooting |
| [install.sh](install.sh) | Installs MariaDB, the FiveM server and txAdmin (runs as a service) |
| [post-install.sh](post-install.sh) | Run after the txAdmin Qbox recipe: adds vMenu, custom car/gun folders, no-NPC-services |
| [add-mod.sh](add-mod.sh) | Downloads a mod straight onto the server and turns it into a FiveM resource |
| [MODS.md](MODS.md) | Status and install steps for each mod we're using |

## Updating the scripts on the server

```bash
cd ~/fivem-qbox-server && git pull
```

## Credits

Mods are **not** included in this repository. They're downloaded from their original pages, and credit goes to
their authors (listed in [MODS.md](MODS.md)).
