# Alfa rtl88xxau Driver Installer for Kali Linux

One-script installer that fixes the Alfa AWUS036ACH (and other rtl88xxau-based adapters) on Kali Linux with kernel 6.15, 6.16, and 6.18, where the default driver fails to compile due to breaking kernel API changes.

## The Problem

After a Kali update to kernel 6.15+, the `realtek-rtl88xxau-dkms` driver fails to build. This breaks monitor mode and packet injection on Alfa adapters — making tools like wifite, airodump-ng, and aircrack-ng unusable.

The errors are caused by three kernel API changes:
- **Kernel 6.15** — `del_timer_sync()` and `from_timer()` were replaced with `timer_delete_sync()` and `timer_container_of()`
- **Kernel 6.16** — a `radio_idx` parameter was added to several cfg80211 wireless functions
- **Kernel 6.18** — `EXTRA_CFLAGS` was removed from the kernel build system; only `ccflags-y` is recognized

This script installs the driver, patches the source code automatically, and builds it directly from source.

## Supported Adapters

| Adapter | Chipset |
|---------|---------|
| Alfa AWUS036ACH | rtl8812au |
| Alfa AWUS036AC | rtl8812au |
| Alfa AWUS1900 | rtl8814au |
| Any rtl88xxau-based adapter | rtl88xxau |

## Requirements

- Kali Linux (tested on 2025.x)
- Linux kernel 6.15 or newer
- Alfa adapter plugged in via USB
- Internet connection (for apt packages)
- Root / sudo access

## Installation

**Option 1 — Clone and run:**
```bash
git clone https://github.com/Ac3rN/realtek-rtl88xxau-auto-installer.git
cd realtek-rtl88xxau-auto-installer
sudo bash install_alfa_driver.sh
```

**Option 2 — One-liner:**
```bash
curl -sL https://raw.githubusercontent.com/Ac3rN/realtek-rtl88xxau-auto-installer/main/install_alfa_driver.sh | sudo bash
```

## What the Script Does

1. Detects your Alfa adapter via `lsusb`
2. Installs build dependencies (`build-essential`, kernel headers, etc.)
3. Removes any old broken driver
4. Installs `realtek-rtl88xxau-dkms` via apt (to get the driver source)
5. Patches the driver source for kernel 6.15 / 6.16 / 6.18 compatibility
6. Builds and installs the kernel module directly from source
7. Blacklists the conflicting in-kernel `rtw88` driver
8. Loads the module and verifies the interface is up

## After Install

Your Alfa adapter will show up as a `wlan` interface (e.g. `wlan0`, `wlan1`). Put it into monitor mode and start scanning:
```bash
sudo airmon-ng check kill
sudo wifite
```

Or manually:
```bash
sudo airmon-ng start wlan0
sudo airodump-ng wlan0mon
```

## Troubleshooting

**No wireless interface after install**
Unplug and replug the Alfa adapter after the script finishes.

**`linux-headers` install fails**
```bash
sudo apt-get install linux-headers-$(uname -r)
```

**Build still fails after patching**
The apt package version may have changed. Check:
```bash
ls /usr/src | grep realtek
dkms status
uname -r
```
Open an issue with the output and your kernel version.

**Adapter detected but no networks showing in wifite**
Make sure interfering processes are killed first:
```bash
sudo airmon-ng check kill
```

## License

MIT
         
