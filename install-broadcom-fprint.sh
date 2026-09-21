#!/usr/bin/env bash
set -euo pipefail

# Check root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script as root or with sudo."
  exit 1
fi

LOG_FILE="/tmp/broadcom_fprint_install.log"
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "=================================================="
echo " Starting Broadcom BCM58200 ControlVault 3 Installer"
echo " Target: Debian 13 (Trixie)"
echo " Log output: ${LOG_FILE}"
echo "=================================================="

# 1. Install System Dependencies
echo "[1/6] Installing build and runtime dependencies..."
apt-get update -qq
apt-get install -y -qq \
    git \
    meson \
    ninja-build \
    gcc \
    g++ \
    pkg-config \
    libglib2.0-dev \
    libgusb-dev \
    libpixman-1-dev \
    libssl-dev \
    libgudev-1.0-dev \
    systemd-dev \
    fprintd \
    binutils \
    zstd \
    curl \
    polkitd

# 2. Build and Install libfprint-tod Base
echo "[2/6] Compiling and installing libfprint-tod base framework..."
BUILD_DIR=$(mktemp -d /tmp/fprint-build.XXXXXX)
cd "${BUILD_DIR}"

git clone --depth 1 -b tod https://gitlab.freedesktop.org/libfprint/libfprint.git libfprint-tod
cd libfprint-tod

meson setup build --prefix=/usr -Dintrospection=false -Ddoc=false
ninja -C build
ninja -C build install

# Verification
if ! pkg-config --modversion libfprint-2-tod-1 >/dev/null 2>&1; then
    echo "Error: libfprint-tod failed to register via pkg-config."
    exit 1
fi

# 3. Download Dell Broadcom TOD Driver Package
echo "[3/6] Fetching Broadcom ControlVault 3 TOD package..."
DRIVER_DIR=$(mktemp -d /tmp/broadcom-pkg.XXXXXX)
cd "${DRIVER_DIR}"

DEB_URL="https://launchpad.net/ubuntu/+archive/primary/+files/libfprint-2-tod1-broadcom_5.15.285-5.15.010.0-0ubuntu2~22.04.1~oem1_amd64.deb"
curl -sSL -o driver.deb "${DEB_URL}"

# Extract package
ar x driver.deb
mkdir -p extracted
tar --zstd -xf data.tar.zst -C extracted

# 4. Deploy Binary Driver, Udev Rules, and Firmware
echo "[4/6] Installing driver modules and firmware binaries..."

# Locate extracted files dynamically
SO_FILE=$(find extracted -name "libfprint-2-tod-1-broadcom.so" -o -name "libfprint-tod-broadcom.so" | head -n 1)
RULES_FILE=$(find extracted -name "*broadcom.rules" | head -n 1)

if [ -z "${SO_FILE}" ] || [ -z "${RULES_FILE}" ]; then
    echo "Error: Driver binaries could not be located in extracted package."
    exit 1
fi

mkdir -p /usr/lib/x86_64-linux-gnu/libfprint-2/tod-1/
mkdir -p /usr/lib/udev/rules.d/
mkdir -p /usr/lib/firmware/broadcom

cp "${SO_FILE}" /usr/lib/x86_64-linux-gnu/libfprint-2/tod-1/
cp "${RULES_FILE}" /usr/lib/udev/rules.d/

# Copy Broadcom SBI firmware files
if [ -d "extracted/var" ]; then
    cp -r extracted/var/* /var/
    if [ -d "extracted/var/lib/fprint" ]; then
        cp -r extracted/var/lib/fprint/* /usr/lib/firmware/broadcom/ 2>/dev/null || true
    fi
fi

# 5. Configure Polkit Authorization Rules
echo "[5/6] Configuring Polkit authorization rules..."
mkdir -p /etc/polkit-1/rules.d/
cat << 'EOF' > /etc/polkit-1/rules.d/50-net.reactivated.fprint.device.enroll.rules
polkit.addRule(function(action, subject) {
    if (action.id == "net.reactivated.fprint.device.enroll" &&
        subject.isInGroup("sudo")) {
        return polkit.Result.YES;
    }
});
EOF

# 6. Apply Rules and Restart Services
echo "[6/6] Reloading system daemons..."
udevadm control --reload-rules && udevadm trigger
systemctl restart fprintd

# Clean up build artifacts
rm -rf "${BUILD_DIR}" "${DRIVER_DIR}"

echo "=================================================="
echo " Installation Complete!"
echo "=================================================="
echo "Verify device initialization by checking logs:"
echo "  sudo journalctl -u fprintd -n 20 --no-pager"
echo ""
echo "Enroll your fingerprint using:"
echo "  fprintd-enroll"
echo "=================================================="
