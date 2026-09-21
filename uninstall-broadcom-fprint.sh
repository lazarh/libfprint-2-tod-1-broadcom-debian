#!/usr/bin/env bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script as root or with sudo."
  exit 1
fi

LOG_FILE="/tmp/broadcom_fprint_uninstall.log"
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "=================================================="
echo " Starting Broadcom BCM58200 ControlVault 3 Uninstaller"
echo " Target: Debian 13 (Trixie)"
echo "=================================================="

# 1. Stop fprintd service
echo "[1/5] Stopping fprintd service..."
systemctl stop fprintd 2>/dev/null || true

# 2. Unhold and purge Ubuntu's libfprint-2-tod1 package
echo "[2/5] Removing package holds and purging TOD packages..."
apt-mark unhold libfprint-2-tod1 2>/dev/null || true
dpkg -P libfprint-2-tod1 2>/dev/null || true

# 3. Delete driver binaries, firmware, and custom links
echo "[3/5] Cleaning up driver binaries, firmware, and overrides..."
rm -rf /usr/lib/x86_64-linux-gnu/libfprint-2/tod-1/
rm -f /usr/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0
rm -f /usr/lib/x86_64-linux-gnu/libfprint-2.so.2
rm -rf /usr/lib/firmware/broadcom/

# 4. Remove custom udev and Polkit rules
echo "[4/5] Removing udev rules and Polkit configurations..."
rm -f /usr/lib/udev/rules.d/60-libfprint-2-device-broadcom.rules
rm -f /usr/lib/udev/rules.d/*broadcom*.rules
rm -f /etc/polkit-1/rules.d/50-net.reactivated.fprint.device.enroll.rules

udevadm control --reload-rules && udevadm trigger 2>/dev/null || true

# 5. Restore stock Debian libfprint-2-2
echo "[5/5] Reinstalling stock Debian libfprint-2-2..."
apt-get update -qq
apt-get install -y --reinstall libfprint-2-2 fprintd

ldconfig
systemctl restart fprintd 2>/dev/null || true

echo "=================================================="
echo " Uninstallation Complete!"
echo " System restored to default stock Debian state."
echo "=================================================="
