#!/usr/bin/env bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script as root or with sudo."
  exit 1
fi

LOG_FILE="/tmp/broadcom_fprint_install.log"
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "=================================================="
echo " Starting Broadcom BCM58200 ControlVault 3 Installer"
echo " Target: Debian 13 (Trixie)"
echo "=================================================="

# 1. Install Runtime Dependencies
echo "[1/4] Installing runtime dependencies..."
apt-get update -qq
apt-get install -y -qq fprintd binutils zstd curl polkitd file

WORK_DIR=$(mktemp -d /tmp/broadcom-install.XXXXXX)
cd "${WORK_DIR}"

# 2. Fetch and configure libfprint-2-tod-1 framework
echo "[2/4] Fetching and configuring libfprint-2-tod-1 framework..."
TOD_URL="https://launchpad.net/ubuntu/+archive/primary/+files/libfprint-2-tod1_1.94.3+tod1-0ubuntu1_amd64.deb"
curl -sSL -o libfprint-tod.deb "${TOD_URL}"

if dpkg -s libfprint-2-2 >/dev/null 2>&1; then
    dpkg --purge --force-depends libfprint-2-2
fi

dpkg -i --force-overwrite libfprint-tod.deb || apt-get install -f -y
apt-mark hold libfprint-2-tod1

# Fix: Instead of overriding the core library file directly (which breaks symbol maps),
# ensure proper symlinking without triggering ldconfig warnings:
rm -f /usr/lib/x86_64-linux-gnu/libfprint-2.so.2
ln -sf libfprint-2-tod.so.1 /usr/lib/x86_64-linux-gnu/libfprint-2.so.2
ldconfig || true

# 3. Download and Extract Broadcom Driver + Firmware
echo "[3/4] Fetching Broadcom ControlVault 3 TOD driver package..."
DRIVER_URL="http://dell.archive.canonical.com/updates/pool/public/libf/libfprint-2-tod1-broadcom/libfprint-2-tod1-broadcom_5.15.285-5.15.010.0-0ubuntu2~22.04.1~oem1_amd64.deb"
curl -sSL -o driver.deb "${DRIVER_URL}"

if ! file driver.deb | grep -q "Debian binary package"; then
    echo "Error: Downloaded driver file is not a valid Debian package."
    exit 1
fi

ar x driver.deb
mkdir -p extracted
tar --zstd -xf data.tar.zst -C extracted

SO_FILE=$(find extracted -name "libfprint-2-tod-1-broadcom.so" -o -name "libfprint-tod-broadcom.so" | head -n 1)
RULES_FILE=$(find extracted -name "*broadcom.rules" | head -n 1)

mkdir -p /usr/lib/x86_64-linux-gnu/libfprint-2/tod-1/
mkdir -p /usr/lib/udev/rules.d/
mkdir -p /usr/lib/firmware/broadcom/

cp "${SO_FILE}" /usr/lib/x86_64-linux-gnu/libfprint-2/tod-1/libfprint-2-tod-broadcom.so
chmod 755 /usr/lib/x86_64-linux-gnu/libfprint-2/tod-1/libfprint-2-tod-broadcom.so

if [ -n "${RULES_FILE}" ]; then
    cp "${RULES_FILE}" /usr/lib/udev/rules.d/
fi

if [ -d "extracted/var/lib/fprint" ]; then
    cp -r extracted/var/lib/fprint/* /usr/lib/firmware/broadcom/ 2>/dev/null || true
    cp -r extracted/var/lib/fprint/* /var/lib/fprint/ 2>/dev/null || true
fi

ldconfig

# 4. Configure Polkit Authorization Rules & Restart Services
echo "[4/4] Configuring Polkit and reloading daemons..."
mkdir -p /etc/polkit-1/rules.d/
cat << 'EOF' > /etc/polkit-1/rules.d/50-net.reactivated.fprint.device.enroll.rules
polkit.addRule(function(action, subject) {
    if (action.id == "net.reactivated.fprint.device.enroll" &&
        subject.isInGroup("sudo")) {
        return polkit.Result.YES;
    }
});
EOF

udevadm control --reload-rules && udevadm trigger
systemctl restart fprintd

rm -rf "${WORK_DIR}"

echo "=================================================="
echo " Installation Complete!"
echo " Run 'fprintd-enroll' to register your fingerprint."
echo "=================================================="
