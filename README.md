# CX Kysona Mouse Battery Driver

An out-of-tree Linux HID driver project intended to expose battery telemetry from a compatible Kysona/CX wireless mouse receiver through the Linux power supply subsystem.

The source is based on a Kysona M600 HID driver originally attributed to **Lode Willems (2024)** and carrying the `GPL-2.0-or-later` SPDX identifier. This repository documents the recovered source, build process, and validation workflow for a CX wireless mouse receiver identified by USB ID `373b:1085`.

> **Project status:** The source baseline has been recovered, but the target-kernel build and runtime behavior must be verified before installation. Compatibility with the target receiver and the accuracy of its reported battery properties have not yet been fully established.

## Table of Contents

- [Overview](#overview)
- [Background](#background)
- [Hardware Compatibility](#hardware-compatibility)
- [Features](#features)
- [How It Works](#how-it-works)
- [Power Supply Properties](#power-supply-properties)
- [Repository Structure](#repository-structure)
- [Requirements](#requirements)
- [Building](#building)
- [Installing](#installing)
- [Verifying the Driver](#verifying-the-driver)
- [Waybar Integration](#waybar-integration)
- [Troubleshooting](#troubleshooting)
- [Uninstallation](#uninstallation)
- [Development Notes](#development-notes)
- [Known Limitations](#known-limitations)
- [Security and Reliability](#security-and-reliability)
- [Contributing](#contributing)
- [Credits and License](#credits-and-license)

## Overview

Wireless mice may expose battery information through vendor-specific Human Interface Device (HID) reports. Depending on the device, receiver, and Linux kernel version, this information may not be available through the standard Linux power supply interface without a suitable driver.

This project provides an out-of-tree Linux HID driver intended to expose battery information from a compatible wireless mouse receiver.

The driver registers a power supply named:

```text
cx-mouse-battery
```

When the driver successfully initializes and registers the power supply, supported battery properties become accessible through the Linux power supply subsystem. Desktop applications and status bars such as Waybar can then use those properties to display battery information.

The project's goals are to:

- Make mouse battery information available on Linux.
- Expose battery status through a standard kernel interface.
- Support periodic battery updates.
- Enable status-bar integration without a separate polling script.
- Document a reproducible build and troubleshooting workflow.

## Background

This repository preserves a recovered source baseline for further development and validation.

The source header identifies the original implementation as a USB HID driver for Kysona M600 mice. The recovered source includes a USB device entry for `373b:1085` and registers a power supply named `cx-mouse-battery`.

The original copyright notice and author attribution are retained. Future changes specific to the target receiver should be documented separately.

The relationship between the original Kysona M600 hardware and the CX receiver has not been fully established. Compatibility should not be assumed beyond the USB identification and hardware tests that have actually been completed.

## Hardware Compatibility

| Property | Value |
|---|---|
| Intended device | CX wireless mouse receiver |
| USB vendor ID | `373b` |
| USB product ID | `1085` |
| USB identifier | `373b:1085` |
| Kernel subsystem | HID / USB |
| Power supply name | `cx-mouse-battery` |
| Primary desktop integration | Waybar |
| Development environment | Linux; Arch Linux is the current target environment |

### Identify the receiver

Connect the receiver and run:

```bash
lsusb -d 373b:1085
```

To list connected USB devices more generally:

```bash
lsusb
```

The presence of this USB ID confirms that the receiver has been enumerated. It does not, by itself, prove that the driver can communicate with the receiver or interpret its battery reports correctly.

### Compatibility scope

Compatibility is intended for the specific receiver identified above.

Other Kysona products, different wireless receivers, devices using similar chipsets, and future hardware revisions are not guaranteed to work.

## Features

The recovered source implements the following behavior:

- **Battery capacity:** Exposes the reported battery percentage.
- **Charging state:** Interprets a device-reported charging indicator.
- **Voltage reporting:** Converts the reported voltage from millivolts to microvolts for the Linux power supply interface.
- **Wired-mode handling:** Uses a wired-mode indicator when determining reported battery status.
- **Periodic polling:** Schedules battery work at a five-second interval.
- **Power supply integration:** Registers a Linux power supply named `cx-mouse-battery`.
- **Status-bar integration:** Can be used by Waybar when the power supply is available and reports the expected properties.

Reporting accuracy, update behavior, and the meaning of each hardware field still require validation on the target device.

## How It Works

The driver connects the HID device to the Linux power supply framework.

The general workflow is:

1. The USB subsystem enumerates the receiver.
2. The HID subsystem identifies and initializes a matching interface.
3. The driver requests or receives device report data.
4. The driver interprets selected report fields as battery telemetry.
5. The driver exposes supported properties through the registered power supply.
6. User-space software reads those properties through the kernel's sysfs interface.

### Report interpretation

The recovered implementation uses the following report-data offsets:

| Field | Interpretation in the implementation |
|---|---|
| `data[2]` | Wired-mode indicator; `1` indicates wired mode |
| `data[6]` | Battery capacity |
| `data[7]` | Charging indicator |
| `data[8:9]` | Battery voltage in millivolts |

These offsets are specific to the recovered implementation. They should not be treated as a universal Kysona protocol specification or applied to unrelated hardware without verification.

### Polling

The source defines:

```c
#define BATTERY_TIMEOUT_MS 5000
```

This configures a five-second interval for the relevant delayed battery work.

It does not guarantee that the hardware updates its report at exactly five-second intervals or that every poll produces a new reading.

## Power Supply Properties

The source declares support for the following Linux power supply properties:

| Property | Purpose |
|---|---|
| `STATUS` | Reports the charging status as interpreted by the driver |
| `PRESENT` | Indicates whether the power supply is present |
| `CAPACITY` | Reports battery capacity as a percentage |
| `SCOPE` | Identifies the power supply's scope |
| `MODEL_NAME` | Exposes the model name provided by the driver |
| `VOLTAGE_NOW` | Reports voltage in microvolts |
| `ONLINE` | Reports the online state according to the driver's internal flag |

The driver converts voltage from millivolts to microvolts by multiplying the reported value by `1000`.

The meaning of `ONLINE` is implementation-specific. Do not change it to represent wired mode without reviewing the power supply behavior and testing the effects on user-space consumers.

### Expected sysfs location

When registration succeeds, the power supply is expected to appear at:

```text
/sys/class/power_supply/cx-mouse-battery/
```

The available files depend on the properties registered by the driver and the behavior of the running kernel.

## Repository Structure

```text
cx-kysona-battery/
├── .gitignore
├── LICENSE
├── Makefile
├── README.md
└── hid-kysona.c
```

| File | Description |
|---|---|
| `hid-kysona.c` | HID driver source |
| `Makefile` | Out-of-tree kernel module build rules |
| `.gitignore` | Excludes generated module and build files |
| `LICENSE` | GPL license text |
| `README.md` | Project documentation |

Compiled kernel modules and generated build files should not be committed to the repository.

## Requirements

You will need:

- A Linux system with a compatible kernel.
- Kernel headers or a build tree matching the kernel you intend to run.
- GNU Make.
- A compatible C compiler and kernel build tools.
- Permission to load kernel modules for runtime testing.
- The target receiver for hardware verification.

### Arch Linux

Install the headers matching your target kernel.

For the standard Arch Linux `linux` kernel:

```bash
sudo pacman -S --needed linux-headers base-devel
```

If you use another kernel package, install the corresponding headers for that kernel instead.

Check the running kernel version:

```bash
uname -r
```

Check whether its build tree is available:

```bash
test -e "/usr/lib/modules/$(uname -r)/build/Makefile" \
  && echo "Kernel build tree found" \
  || echo "Matching kernel build tree not found"
```

If you have upgraded your kernel but have not rebooted, the running kernel and installed headers may not match. Build for the intended kernel and test after booting into that same version.

## Building

Clone the repository:

```bash
git clone https://github.com/nebularch/cx-kysona-battery.git
cd cx-kysona-battery
```

Build the module for the running kernel:

```bash
make
```

To build against a particular installed kernel, set `KDIR` to that kernel's build directory. Replace the example version below with the actual directory name under `/usr/lib/modules/`:

```bash
make KDIR="/usr/lib/modules/6.x.y-arch1-1/build"
```

Clean generated build files:

```bash
make clean
```

Inspect the resulting module:

```bash
modinfo ./hid-kysona.ko
```

Check its kernel compatibility metadata:

```bash
modinfo -F vermagic ./hid-kysona.ko
```

### Build compatibility

The module must be built for the kernel that will load it. A module built for one kernel version should not be assumed to work with another.

A successful build proves only that compilation completed. It does not establish that:

- The driver successfully probes the target receiver.
- The HID reports are interpreted correctly.
- Battery readings are accurate.
- Wired-mode behavior is correct.
- The module can safely claim the intended HID interface alongside other interfaces.

## Installing

**Installation has not yet been established as a verified, automated procedure for this repository.**

Before installing:

1. Review the source and confirm that you understand the applicable license terms.
2. Build against the intended kernel.
3. Review the module metadata.
4. Keep a working kernel and a recovery path available.
5. Check whether another driver already claims the target interface.
6. Review kernel logs during testing.

A typical manual out-of-tree module installation uses a kernel-specific directory under:

```text
/usr/lib/modules/<kernel-version>/updates/
```

Replace `<kernel-version>` with the actual kernel version. After installing the module in the appropriate location, refresh the module dependency metadata for that kernel.

For example, after installing the module:

```bash
sudo depmod 6.x.y-arch1-1
modinfo -k 6.x.y-arch1-1 -n hid_kysona
```

Replace `6.x.y-arch1-1` in both commands with the actual kernel version. Confirm the resolved module path before loading the module.

Do not overwrite another working module or load a module built for a different kernel version.

Secure Boot and distribution-specific module-signing policies may prevent an unsigned custom module from loading.

## Verifying the Driver

### 1. Confirm USB enumeration

```bash
lsusb -d 373b:1085
```

### 2. Inspect kernel logs

After attempting to load the driver or reconnecting the receiver:

```bash
sudo journalctl -k -b --no-pager \
  | grep -iE 'kysona|hid|battery'
```

Look for probe failures, report errors, power supply registration errors, or module compatibility issues.

### 3. Check the power supply

```bash
ls -d /sys/class/power_supply/cx-mouse-battery 2>/dev/null
```

If the directory exists, inspect its available properties:

```bash
for file in /sys/class/power_supply/cx-mouse-battery/*; do
    [ -f "$file" ] || continue
    printf '%s: ' "${file##*/}"
    cat "$file"
done
```

This reads the available sysfs values without modifying the device.

### 4. Verify the reported values

Compare the reported capacity, charging state, voltage, and online state with the actual device behavior.

Repeat the checks while charging, disconnecting, reconnecting, and switching between wired and wireless operation, where supported.

Do not rely on the driver's values for critical decisions. This is a custom hardware integration that may report stale or incorrect telemetry.

## Waybar Integration

If the driver successfully registers the `cx-mouse-battery` power supply, Waybar can use it to display battery information.

Example JSONC module:

```jsonc
"battery#mouse": {
    "bat": "cx-mouse-battery",
    "interval": 5,
    "format": "󰍽 {capacity}%",
    "format-charging": "󰍽  {capacity}%"
}
```

Add `battery#mouse` to the appropriate module list in your Waybar configuration.

Restart Waybar after saving the changes.

### If the module does not appear

Check the power supply independently:

```bash
cat /sys/class/power_supply/cx-mouse-battery/capacity
cat /sys/class/power_supply/cx-mouse-battery/status
```

A file may be unavailable if the power supply was not registered or the expected property is not exposed.

If the sysfs values are correct but Waybar still shows nothing, investigate the Waybar configuration and logs before modifying the driver.

## Troubleshooting

### The build fails

- Check that the kernel build tree exists.
- Confirm that the headers match the intended kernel.
- Read the first compiler error rather than focusing only on the final `make` failure.
- Inspect recent source changes.
- Run `make clean` before rebuilding when appropriate.

### The USB device is missing

- Confirm that the receiver is connected.
- Check the output of `lsusb`.
- Try another USB port if appropriate.
- Inspect kernel logs.
- Confirm that the source includes the intended USB ID.

### The module fails to load

- Check that it was built for the active kernel.
- Inspect `modinfo` and the module's `vermagic`.
- Check kernel logs for symbol, signing, or probe errors.
- Verify Secure Boot and module-signing requirements.
- Check whether another driver already claims the target interface.

### The power supply is missing

- Verify that the module loaded.
- Check for HID probe and power supply registration errors.
- Confirm that the intended USB interface matches the driver.
- Check that the module was installed for the active kernel.

### The battery percentage is incorrect

- Inspect the values exposed by the driver.
- Verify the expected interpretation of the report fields.
- Check the device state and reconnect the receiver.
- Compare the reported reading with a known device state before changing the parsing logic.

### The charging icon is incorrect

- Inspect the power supply's `status` and `online` properties.
- Review the wired-mode and charging-state logic.
- Do not assume that wired mode and charging state are interchangeable.
- Test any changes against actual hardware before relying on them.

### The module disappears after a kernel upgrade

Out-of-tree modules may need to be rebuilt for a new kernel version.

Rebuild against that kernel's matching headers, install the resulting module for the correct version, refresh the module dependency metadata, and verify the resolved module path before loading it.

## Uninstallation

Reverse the installation steps used on your system.

In general:

1. Identify the exact custom module file installed for the target kernel.
2. Remove only that custom module file.
3. Remove any custom module-loading configuration created for this driver.
4. Refresh module dependency metadata for the affected kernel.
5. Reboot or unload the driver when it is safe to do so.
6. Verify that the custom module is no longer being selected.

Do not remove distribution-provided HID modules or unrelated kernel files. If the driver has claimed a HID interface, avoid forcibly unbinding other interfaces—particularly a keyboard interface—without understanding the consequences.

## Development Notes

The current source should be treated as a recovered baseline.

Before making functional changes:

- Preserve the original author's copyright notice and SPDX identifier.
- Keep a known-good copy of the source.
- Document the reason for each change.
- Build against the intended kernel.
- Inspect module logs and power supply values.
- Test wireless and wired operation separately, where applicable.
- Verify Waybar behavior independently of driver behavior.
- Avoid committing compiled kernel modules or unrelated machine configuration.

Changes to `ONLINE`, charging status, report parsing, polling, and interface matching should be accompanied by explicit hardware test results.

## Known Limitations

- Full compatibility with the target receiver has not been independently established.
- Battery report interpretation is based on the recovered implementation.
- Kernel compatibility must be verified for each target version.
- Battery readings may be stale or unavailable when the receiver or mouse is asleep or disconnected.
- Wired-mode and charging semantics require hardware verification.
- The repository does not currently provide a verified automated installer or DKMS workflow.
- Other Kysona products and similar receivers are not guaranteed to work.
- Runtime testing is required before the driver can be considered reliable.

## Security and Reliability

Kernel modules execute with kernel-level privileges. Only build and load source you trust.

Before testing:

- Review changes to the driver source.
- Keep a working kernel available.
- Avoid loading modules compiled for an incompatible kernel.
- Do not unbind unrelated HID interfaces.
- Do not commit access tokens, passwords, private keys, or other secrets.
- Keep logs focused on relevant driver diagnostics.

This project is provided for development and hardware experimentation. It is not a substitute for careful kernel-level testing.

## Contributing

Bug reports, build fixes, documentation improvements, and verified hardware observations are welcome.

When reporting a problem, include:

- Linux distribution and kernel version.
- Receiver USB ID.
- Build command and relevant build errors.
- Relevant kernel log messages.
- Available power supply properties.
- Reproduction steps.
- Whether the issue occurs in wired mode, wireless mode, or both.

Remove secrets and unrelated personal information from logs before sharing them.

## Credits and License

The source header attributes the original Kysona M600 HID driver to:

**Lode Willems** — Copyright (c) 2024.

The recovered source declares:

```text
SPDX-License-Identifier: GPL-2.0-or-later
```

The original copyright notice and license identifier must remain intact. Verify the source's provenance and applicable license terms before redistributing it, and retain the required copyright and license notices.

Hardware-specific adaptations, testing results, and documentation changes should be clearly distinguished from the original author's work.

See [`LICENSE`](LICENSE) for the included license text.

---

**Repository:** [nebularch/cx-kysona-battery](https://github.com/nebularch/cx-kysona-battery)

## Installation on Arch Linux (DKMS)

DKMS automatically rebuilds the `hid-kysona` kernel module when a compatible kernel update is installed, provided the corresponding kernel headers are available.

### Requirements

Install DKMS, the headers for your installed kernel, and the standard build tools:

```bash
sudo pacman -S --needed dkms linux-headers base-devel
```

If you use a different kernel package, install its matching headers instead of `linux-headers`.

### Install the driver

From the repository directory, copy the driver files into the DKMS source directory:

```bash
sudo install -d /usr/src/hid-kysona-0.1.0
sudo install -m 644 hid-kysona.c Makefile dkms.conf \
    /usr/src/hid-kysona-0.1.0/
```

Register and install the module:

```bash
sudo dkms add -m hid-kysona -v 0.1.0
sudo dkms build -m hid-kysona -v 0.1.0
sudo dkms install -m hid-kysona -v 0.1.0
sudo depmod -a
```

If version `0.1.0` is already registered, skip `dkms add`. If it is already built or installed, check `dkms status` before deciding whether to rebuild or reinstall. Do not remove an existing registration just to repeat these commands.

Configure the module to load at startup:

```bash
echo hid_kysona | sudo tee /etc/modules-load.d/hid_kysona.conf
```

Reboot and verify the driver and battery supply.

### Verify installation

```bash
dkms status
modinfo -n hid_kysona
lsmod | grep '^hid_kysona'
cat /sys/class/power_supply/cx-mouse-battery/{capacity,status}
```

The module path should normally point to the DKMS installation under `/updates/dkms/`. The battery supply is available only when a supported device is detected and the driver probes successfully.

### Kernel updates

Before updating the kernel, ensure its matching headers are installed. After the update, check:

```bash
dkms status
```

If the module was not rebuilt for the new kernel, install the matching headers and rebuild it:

```bash
sudo dkms autoinstall
```

Then check the DKMS build logs if necessary:

```bash
find /var/lib/dkms/hid-kysona -name make.log -print
```

### Uninstall

### Uninstall

Remove the DKMS installation for this version:

```bash
sudo dkms remove -m hid-kysona -v 0.1.0 --all
sudo rm -f /etc/modules-load.d/hid_kysona.conf
sudo depmod -a
```

DKMS may restore a previously archived, distribution-provided module when removing its replacement. Check which module will be selected:

```bash
modinfo -n hid_kysona
dkms status
```

If the mouse is still connected, verify that its battery reporting and driver binding work as expected. Reboot if necessary to load the restored module.

Once you have confirmed that you no longer need the DKMS source, remove `/usr/src/hid-kysona-0.1.0/` manually. Do not delete it while you still intend to use or rebuild this DKMS version.
