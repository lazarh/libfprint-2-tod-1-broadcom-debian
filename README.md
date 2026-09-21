# Broadcom ControlVault 3 Fingerprint Reader Setup for Debian 13 (Trixie)

Automated scripts to build `libfprint-tod`, extract the Broadcom ControlVault 3 proprietary drivers/firmware, and set up fingerprint authentication on Debian 13 (Trixie).

Tested on Dell laptops equipped with the **Broadcom BCM58200 ControlVault 3** (`USB ID 0a5c:5843`) sensor.

---

## 📋 Overview

Stock Debian 13 does not ship with `libfprint-tod` (Touch-OEM Driver support) or the proprietary Broadcom firmware required for ControlVault 3 hardware. 

This repository provides two scripts:
1. `install-broadcom-fprint.sh` – Compiles `libfprint-tod`, extracts the Broadcom TOD driver and SBI firmware, sets up Polkit authorization rules, and flashes/initializes the sensor.
2. `uninstall-broadcom-fprint.sh` – Removes all installed driver binaries, firmware, Polkit rules, and custom `libfprint` libraries.

---

## 🛠 Prerequisite Hardware & OS

* **OS**: Debian 13 (Trixie) / Testing
* **Device**: Broadcom Corp. 58200 ControlVault 3 (`0a5c:5843`)
* **Packages**: `sudo`, `curl`, `git`

Verify your hardware ID before proceeding:
```bash
lsusb | grep -i broadcom
# Expected output: Bus XXX Device YYY: ID 0a5c:5843 Broadcom Corp. 58200
```
## 🚀 Installation
Clone this repository:
```bash
git clone [https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git](https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git)
cd YOUR_REPO_NAME
```
Make the installer executable and run it with sudo
```bash
chmod +x install-broadcom-fprint.sh
sudo ./install-broadcom-fprint.sh
```
Enroll your fingerprint
```bash
fprintd-enroll
```
Verify finger matching:
```bash
fprintd-verify
```
## 🗑 Uninstallation
To cleanly remove all components and restore default system state:
```bash
chmod +x uninstall-broadcom-fprint.sh
sudo ./uninstall-broadcom-fprint.sh
```
## 🔧 Troubleshooting
Firmware Flashing Delay
During the initial run, the Broadcom driver flashes the Secure Boot Image (bcmsbiCitadelA0_7.otp) and resets the USH coprocessor. This process takes approximately 1 minute.
You can monitor the live initialization progress via journalctl:
```bash
sudo journalctl -f -u fprintd
```
Permission Denied During Enrollment
If fprintd-enroll fails with GDBus.Error:net.reactivated.Fprint.Error.PermissionDenied:
Ensure your user account belongs to the sudo group:
```bash
sudo usermod -aG sudo $USER
```
Re-log into your shell session to refresh group memberships.

##📄 License
The shell scripts in this repository are licensed under the MIT License. Broadcom firmware binaries and proprietary driver modules downloaded during installation belong to their respective copyright holders.

