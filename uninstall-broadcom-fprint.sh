#!/usr/bin/env bash
set -euo pipefail

# Check root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script as root or with sudo."
  exit 1
fi

echo "=================================================="
echo " Starting Broadcom BCM58200 & libfprint Removal"
echo "=================================================="

# 1. Stop fprintd service
echo "[1/4] Stopping fprintd daemon..."
systemctl stop fprintd.service 2>/dev/null || true

# 2. Remove Broadcom Driver, Firmware, and Polkit Rules
echo "[2/4] Removing Broadcom driver, firmware, and rules..."
rm -f /usr/lib/x86_64-linux-gnu/libfprint-2/tod-1/libfprint-2-tod-1-broadcom.so
rm -f /usr/lib/x86_64-linux-gnu/libfprint-2/tod-1/libfprint-tod-broadcom.so
rm -f /usr/lib/udev/rules.d/*broadcom.rules
rm -f /etc/polkit-1/rules.d/50-net.reactivated.fprint.device.enroll.rules
rm -rf /usr/lib/firmware/broadcom
rm -rf /var/lib/fprint

# 3. Uninstall compiled libfprint-tod shared libraries and headers
echo "[3/4] Removing installed libfprint-tod files..."
rm -f /usr/lib/x86_64-linux-gnu/libfprint-2.so*
rm -f /usr/lib/x86_64-linux-gnu/pkgconfig/libfprint-2-tod-1.pc
rm -f /usr/lib/x86_64-linux-gnu/pkgconfig/libfprint-2.pc
rm -rf /usr/include/libfprint-2

# 4. Reload System Daemons
echo "[4/4] Reloading system daemons..."
udevadm control --reload-rules && udevadm trigger
systemctl restart fprintd 2>/dev/null || true

echo "=================================================="
echo " Removal Complete!"
echo " All driver, firmware, and libfprint-tod files removed."
echo "=================================================="
