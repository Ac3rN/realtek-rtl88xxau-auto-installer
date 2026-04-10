# realtek-rtl88xxau-auto-installer
One-script installer that fixes Alfa rtl88xxau adapter driver compilation on Kali Linux kernel 6.15 and 6.16           

# Alfa rtl88xxau Driver Installer for Kali Linux

One-script installer that fixes the Alfa AWUS036ACH (and other rtl88xxau-based adapters) on Kali Linux with kernel 6.15 and 6.16, where the default driver fails to compile due to breaking kernel API changes.

## The Problem

After a Kali update to kernel 6.15 or 6.16, the `realtek-rtl88xxau-dkms` driver fails to build. This breaks monitor mode and packet injection on Alfa adapters — making tools like wifite, airodump-ng, and aircrack-ng unusable.

The errors are caused by two kernel API changes:
- **Kernel 6.15** — `del_timer_sync()` and `from_timer()` were replaced with `timer_delete_sync()` and `timer_container_of()`
- **Kernel 6.16** — a `radio_idx` parameter was added to several cfg80211 wireless functions

This script installs the driver and patches the source code automatically before compiling.

## Supported Adapters

| Adapter | Chipset |
|---------|---------|
| Alfa AWUS036ACH | rtl8812au |
| Alfa AWUS036AC | rtl8812au |
| Alfa AWUS1900 | rtl8814au |
| Any rtl88xxau-based adapter | rtl88xxau |

## Requirements

- Kali Linux (tested on 2025.x)
- Linux kernel 6.15 or 6.16
- Alfa adapter plugged in via USB
- Internet connection (for apt packages)
- Root / sudo access

## Installation

**Option 1 — Download and run:**
```bash
git clone https://github.com/<your-username>/<your-repo>.git
cd <your-repo>
sudo bash install_alfa_driver.sh
```

**Option 2 — One-liner:**
```bash
curl -sL https://raw.githubusercontent.com/<your-username>/<your-repo>/main/install_alfa_driver.sh | sudo bash
```

## What the Script Does

1. Detects your Alfa adapter via `lsusb`
2. Installs build dependencies (`dkms`, `build-essential`, kernel headers, etc.)
3. Removes any old broken driver
4. Installs `realtek-rtl88xxau-dkms` via apt
5. Patches the driver source for kernel 6.15+ and 6.16+ compatibility
6. Rebuilds and installs the DKMS module
7. Loads the module and verifies the interface is up

## After Install

Put the adapter into monitor mode and start scanning:
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

**DKMS build still fails after patching**
The apt package version may have changed. Check:
```bash
ls /usr/src | grep realtek
dkms status
```
Open an issue with the output and your kernel version (`uname -r`).

**Adapter detected but no networks showing in wifite**
Make sure interfering processes are killed first:
```bash
sudo airmon-ng check kill
```

## License

MIT
