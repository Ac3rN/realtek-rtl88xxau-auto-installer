#!/bin/bash
# =============================================================================
# Alfa AWUS036ACH rtl88xxau Driver Installer for Kali Linux
# =============================================================================
#
# Supported adapters:
#   - Alfa AWUS036ACH  (rtl8812au chipset)
#   - Alfa AWUS036AC   (rtl8812au chipset)
#   - Alfa AWUS1900    (rtl8814au chipset)
#   - Any adapter using the rtl88xxau driver
#
# Tested on:
#   - Kali Linux 2025.x
#   - Linux kernel 6.15 and 6.16
#
# What this script does:
#   1. Installs all required build dependencies
#   2. Removes any broken existing driver
#   3. Installs realtek-rtl88xxau-dkms via apt
#   4. Patches source code for kernel 6.15+ and 6.16+ compatibility
#   5. Rebuilds and loads the DKMS kernel module
#
# Usage:
#   sudo bash install_alfa_driver.sh
#
# One-liner install (after uploading to GitHub):
#   curl -sL <raw_url> | sudo bash
#
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${GREEN}[+]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[-]${NC} $1"; exit 1; }
section() { echo -e "\n${BLUE}──────────────────────────────────────────${NC}"; echo -e "${BLUE}    $1${NC}"; echo -e "${BLUE}──────────────────────────────────────────${NC}"; }

[ "$EUID" -ne 0 ] && error "Run as root: sudo bash $0"

KERNEL=$(uname -r)
DISTRO=$(grep ^ID= /etc/os-release 2>/dev/null | cut -d= -f2)

section "Alfa rtl88xxau Driver Installer"
info "Kernel : $KERNEL"
info "Distro : $DISTRO"
echo ""

# ── 1. Check adapter is plugged in ───────────────────────────────────────────
section "Step 1: Checking for Alfa adapter"
if lsusb | grep -qiE "realtek|0bda:"; then
    info "Realtek USB adapter detected:"
    lsusb | grep -iE "realtek|0bda:" | sed 's/^/        /'
else
    warn "No Realtek USB adapter detected — make sure it is plugged in"
    warn "Continuing anyway..."
fi

# ── 2. Dependencies ───────────────────────────────────────────────────────────
section "Step 2: Installing dependencies"
apt-get update -qq
apt-get install -y \
    dkms \
    python3 \
    bc \
    build-essential \
    libelf-dev \
    git \
    curl \
    linux-headers-"$KERNEL" 2>/dev/null || \
apt-get install -y \
    dkms \
    python3 \
    bc \
    build-essential \
    libelf-dev \
    git \
    curl \
    linux-headers-generic
info "Dependencies installed"

# ── 3. Remove old driver ──────────────────────────────────────────────────────
section "Step 3: Removing old driver"
apt-get remove -y realtek-rtl88xxau-dkms 2>/dev/null && info "Removed old apt package" || true
dkms remove rtl88xxau/5.6.4.2 --all 2>/dev/null && info "Removed old DKMS module" || true
modprobe -r 88XXau 2>/dev/null && info "Unloaded old kernel module" || true

# ── 4. Install driver package ─────────────────────────────────────────────────
section "Step 4: Installing realtek-rtl88xxau-dkms"
apt-get install -y realtek-rtl88xxau-dkms
info "Package installed"

# ── 5. Locate driver source ───────────────────────────────────────────────────
section "Step 5: Locating driver source"
SRC_DIR=$(find /usr/src -maxdepth 1 -type d -name "realtek-rtl88xxau*" | sort | tail -1)
[ -z "$SRC_DIR" ] && error "Driver source not found in /usr/src — apt install may have failed"
info "Found: $SRC_DIR"

# ── 6. Apply kernel compatibility patches ─────────────────────────────────────
section "Step 6: Applying kernel compatibility patches"
info "Patching for kernel 6.15+ and 6.16+ compatibility..."

python3 - "$SRC_DIR" <<'PYEOF'
import sys, os

src = sys.argv[1]
patched = 0
skipped = 0

def patch(filepath, old, new, label):
    global patched, skipped
    if not os.path.exists(filepath):
        print(f"  [!] File not found, skipping: {filepath}")
        return
    with open(filepath, 'r') as f:
        c = f.read()
    if old in c:
        c = c.replace(old, new)
        with open(filepath, 'w') as f:
            f.write(c)
        print(f"  [+] Patched: {label}")
        patched += 1
    else:
        print(f"  [=] Already patched or not needed: {label}")
        skipped += 1

# ── osdep_service_linux.h — timer API changes in kernel 6.15 ─────────────────
p1 = os.path.join(src, "include/osdep_service_linux.h")

patch(p1,
    "#if (LINUX_VERSION_CODE >= KERNEL_VERSION(4, 14, 0))\n\t_timer *ptimer = from_timer(ptimer, in_timer, timer);\n#else",
    "#if (LINUX_VERSION_CODE >= KERNEL_VERSION(6, 15, 0))\n\t_timer *ptimer = timer_container_of(ptimer, in_timer, timer);\n#elif (LINUX_VERSION_CODE >= KERNEL_VERSION(4, 14, 0))\n\t_timer *ptimer = from_timer(ptimer, in_timer, timer);\n#else",
    "timer_container_of (kernel 6.15+)")

patch(p1,
    "\t*bcancelled = del_timer_sync(&ptimer->timer) == 1 ? 1 : 0;",
    "#if (LINUX_VERSION_CODE >= KERNEL_VERSION(6, 15, 0))\n\t*bcancelled = timer_delete_sync(&ptimer->timer) == 1 ? 1 : 0;\n#else\n\t*bcancelled = del_timer_sync(&ptimer->timer) == 1 ? 1 : 0;\n#endif",
    "timer_delete_sync (kernel 6.15+)")

# ── ioctl_cfg80211.c — radio_idx parameter added in kernel 6.16 ───────────────
p2 = os.path.join(src, "os_dep/linux/ioctl_cfg80211.c")

patch(p2,
    "static int cfg80211_rtw_set_wiphy_params(struct wiphy *wiphy, u32 changed)",
    "static int cfg80211_rtw_set_wiphy_params(struct wiphy *wiphy,\n#if (LINUX_VERSION_CODE >= KERNEL_VERSION(6, 16, 0))\n\tint radio_idx,\n#endif\n\tu32 changed)",
    "set_wiphy_params radio_idx (kernel 6.16+)")

patch(p2,
    "\tstruct wireless_dev *wdev,\n#endif\n#if (LINUX_VERSION_CODE >= KERNEL_VERSION(2, 6, 36)) || defined(COMPAT_KERNEL_RELEASE)\n\tenum nl80211_tx_power_setting type, int mbm)",
    "\tstruct wireless_dev *wdev,\n#endif\n#if (LINUX_VERSION_CODE >= KERNEL_VERSION(6, 16, 0))\n\tint radio_idx,\n#endif\n#if (LINUX_VERSION_CODE >= KERNEL_VERSION(2, 6, 36)) || defined(COMPAT_KERNEL_RELEASE)\n\tenum nl80211_tx_power_setting type, int mbm)",
    "set_tx_power radio_idx (kernel 6.16+)")

patch(p2,
    "#if (LINUX_VERSION_CODE >= KERNEL_VERSION(6, 14, 0))\n\tunsigned int link_id,\n#endif\n\tint *dbm)",
    "#if (LINUX_VERSION_CODE >= KERNEL_VERSION(6, 16, 0))\n\tint radio_idx,\n\tunsigned int link_id,\n#elif (LINUX_VERSION_CODE >= KERNEL_VERSION(6, 14, 0))\n\tunsigned int link_id,\n#endif\n\tint *dbm)",
    "get_tx_power radio_idx (kernel 6.16+)")

print(f"\n  Patching summary: {patched} applied, {skipped} already done/not needed")
PYEOF

# ── 7. Rebuild DKMS module ────────────────────────────────────────────────────
section "Step 7: Rebuilding DKMS module"
info "Building for kernel $KERNEL — this may take a minute..."

DKMS_NAME=$(dkms status | grep rtl88xxau | awk -F'[,: ]+' '{print $1}' | head -1)
DKMS_VER=$(dkms status  | grep rtl88xxau | awk -F'[,: ]+' '{print $2}' | head -1)

[ -z "$DKMS_NAME" ] && error "DKMS module not registered — check apt install output above"

dkms build   "$DKMS_NAME"/"$DKMS_VER" -k "$KERNEL"
dkms install "$DKMS_NAME"/"$DKMS_VER" -k "$KERNEL" --force
info "DKMS module built and installed"

# ── 8. Load module ────────────────────────────────────────────────────────────
section "Step 8: Loading kernel module"
modprobe -r 88XXau 2>/dev/null || true
if modprobe 88XXau 2>/dev/null; then
    info "Module loaded successfully"
else
    warn "Could not load module automatically — try replugging the adapter"
fi

# ── 9. Final status ───────────────────────────────────────────────────────────
section "Done"
info "Adapter check:"
if ip link show | grep -E "wlan|alfa"; then
    echo ""
    info "Wireless interface is up and ready"
else
    warn "No wireless interface visible yet — replug your Alfa adapter"
fi

echo ""
info "To start using with wifite:"
echo "    sudo airmon-ng check kill"
echo "    sudo wifite"
echo ""
info "To put adapter in monitor mode manually:"
echo "    sudo airmon-ng start wlan0"
echo "    sudo airodump-ng wlan0mon"
echo ""
