# CX Kysona Mouse Battery Driver

A custom Linux HID driver project for exposing battery telemetry from a compatible Kysona/CX wireless mouse receiver through the Linux power supply subsystem.

The project is based on a Kysona M600 HID driver originally attributed to **Lode Willems (2024)** and carrying the `GPL-2.0-or-later` SPDX identifier. This repository focuses on documenting, building, and validating its use with the CX wireless mouse receiver identified by USB ID `373b:1085`.

> **Project status:** Source baseline recovered; target-kernel build and runtime behavior must be verified before installation. Compatibility with the specific receiver and all reported battery properties should be confirmed on hardware.

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

Wireless mice may expose battery information through vendor-specific Human Interface Device (HID) reports. Depending on the device, receiver, and Linux kernel version, this information may not be available through the standard power supply interface without a suitable driver.

This project provides an out-of-tree Linux HID driver intended to expose battery information for a compatible wireless mouse receiver.

The driver registers a power supply named:

```text
cx-mouse-battery
```

When successfully detected and initialized, supported battery properties can be accessed through Linux's power supply subsystem. Desktop applications and status bars such as Waybar can then use those properties to display battery information.

The intended goals are:

- Make mouse battery information available on Linux.
- Expose battery status through a standard kernel interface.
- Support periodic battery updates.
- Allow status-bar integration without a separate polling script.
- Document a reproducible build and troubleshooting workflow.

## Background

This repository preserves a recovered source baseline for further development and validation.

The source header identifies the original implementation as a USB HID driver for Kysona M600 mice. The recovered copy includes a USB device entry for `373b:1085` and registers a power supply called `cx-mouse-battery`.

The original author's work and copyright notice are retained. Changes made specifically for this receiver should be documented separately in future commits.

The exact hardware relationship between the original Kysona M600 target and the CX receiver should not be assumed beyond what has been confirmed through USB identification and testing.

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

For a broader view of connected USB devices:

```bash
lsusb
```

The presence of the USB ID confirms device enumeration only. It does not by itself prove that the driver can communicate with the receiver or that its battery reports are interpreted correctly.

### Compatibility scope

Compatibility is intended for the specific receiver described above.

Other Kysona products, different wireless receivers, devices using similar chipsets, and future hardware revisions are not guaranteed to work.

## Features

The recovered source implements the following behavior:

- **Battery capacity:** Exposes the reported battery percentage.
- **Charging state:** Interprets a device-reported charging indicator.
- **Voltage reporting:** Converts the reported voltage from millivolts to microvolts for the Linux power supply interface.
- **Wired-mode handling:** Includes a wired-mode flag used when determining reported battery status.
- **Periodic polling:** Uses a five-second battery work interval.
- **Power supply integration:** Registers a Linux power supply device named `cx-mouse-battery`.
- **Status-bar integration:** Can be referenced by Waybar when the power supply is available.

Actual reporting accuracy, update behavior, and the semantics of each hardware field still require validation on the target device.

## How It Works

The driver connects the HID device to Linux's power supply framework.

The general workflow is:

1. The USB subsystem enumerates the receiver.
2. The HID subsystem identifies and initializes a matching interface.
3. The driver requests or receives device report data.
4. The implementation interprets selected report fields as battery telemetry.
5. The driver exposes supported properties through the registered power supply.
6. User-space software reads those properties through the kernel's sysfs interface.

### Report interpretation

The recovered implementation uses these report-data offsets:

| Field | Interpretation in the implementation |
|---|---|
| `data[2]` | Wired-mode indicator; value `1` indicates wired mode |
| `data[6]` | Battery capacity |
| `data[7]` | Charging indicator |
| `data[8:9]` | Battery voltage in millivolts |

These offsets are implementation-specific. They must not be treated as a universal Kysona protocol specification or applied to unrelated hardware without verification.

### Polling

The source defines:

```c
#define BATTERY_TIMEOUT_MS 5000
```

This configures a five-second interval for the relevant delayed battery work.

The interval does not guarantee that the hardware updates its report at exactly five-second intervals, nor that every poll produces a new reading.

## Power Supply Properties

The source declares support for these Linux power supply properties:

| Property | Purpose |
|---|---|
| `STATUS` | Charging, discharging, or unknown status |
| `PRESENT` | Indicates the power supply is present |
| `CAPACITY` | Battery capacity percentage |
| `SCOPE` | Identifies the supply scope |
| `MODEL_NAME` | Device model name exposed by the driver |
| `VOLTAGE_NOW` | Voltage in microvolts |
| `ONLINE` | Online state according to the driver's internal flag |

The driver converts voltage from millivolts to microvolts by multiplying the reported value by `1000`.

The meaning of `ONLINE` is implementation-specific. It should not be changed to mean wired mode without reviewing the power supply behavior and testing the effect on desktop consumers.

### Expected sysfs location

When registration succeeds, the power supply is expected at:

```text
/sys/class/power_supply/cx-mouse-battery/
```

The available files depend on the registered properties and kernel behavior.

## Repository Structure

```text
cx-kysona-battery/
├── .gitignore
├── Makefile
├── README.md
└── hid-kysona.c
```

| File | Description |
|---|---|
| `hid-kysona.c` | HID driver source |
| `Makefile` | Out-of-tree kernel module build rules |
| `.gitignore` | Excludes generated module and build files |
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

For the standard Arch `linux` kernel:

```bash
sudo pacman -S --needed linux-headers base-devel
```

For another kernel package, install that kernel's corresponding headers instead.

Check the current kernel:

```bash
uname -r
```

Check that its build tree is available:

```bash
test -e "/usr/lib/modules/$(uname -r)/build/Makefile" \
  && echo "Kernel build tree found" \
  || echo "Matching kernel build tree not found"
```

If you have upgraded your kernel but have not rebooted, the running kernel and installed headers may not match. Build for the intended kernel and test after booting into that same version.

## Building

Clone the repository after it has been published:

```bash
git clone https://github.com/nebularch/cx-kysona-battery.git
cd cx-kysona-battery
```

Build for the running kernel:

```bash
make
```

Build against a particular installed kernel build tree:

```bash
make KDIR=/usr/lib/modules/<kernel-version>/build
```

Replace `<kernel-version>` with the actual directory name under `/usr/lib/modules/`.

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
- The module is safe to load alongside other HID interfaces.

## Installing

**Installation has not yet been established as a verified, automated procedure for this repository.**

Before installing:

1. Confirm that the source is correct and its license is understood.
2. Build against the intended kernel.
3. Review the kernel module metadata.
4. Keep a working kernel and a recovery path available.
5. Check whether another driver already claims the target interface.
6. Review kernel logs after testing.

A typical manual out-of-tree module installation uses a kernel-specific directory under:

```text
/usr/lib/modules/<kernel-version>/updates/
```

After placing the module in the appropriate location, module dependency metadata must be refreshed for that kernel. Verify the resolved module path before loading it.

For example, after installing to the appropriate directory:

```bash
sudo depmod <kernel-version>
modinfo -k <kernel-version> -n hid_kysona
```

Use the actual kernel version. Do not overwrite another working module or load a module built for a different kernel version.

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

Look for probe failures, report errors, registration errors, or module compatibility issues.

### 3. Check the power supply

```bash
ls -d /sys/class/power_supply/cx-mouse-battery 2>/dev/null
```

If the directory exists, inspect its properties:

```bash
for file in /sys/class/power_supply/cx-mouse-battery/*; do
    [ -f "$file" ] || continue
    printf '%s: ' "${file##*/}"
    cat "$file"
done
```

This reads the available sysfs values without modifying the device.

### 4. Verify the reported values

Compare the capacity, charging state, voltage, and online state with the actual device behavior.

Repeat the check after charging, disconnecting, reconnecting, and switching between wired and wireless operation where supported.

Do not rely on the driver's values for critical decisions. This is a custom hardware integration and may report stale or incorrect telemetry.

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

Add `battery#mouse` to the appropriate Waybar module list in your configuration.

Restart Waybar after saving changes.

### If the module does not appear

Check the power supply independently first:

```bash
cat /sys/class/power_supply/cx-mouse-battery/capacity
cat /sys/class/power_supply/cx-mouse-battery/status
```

A file may be unavailable if the power supply was not registered or the property is not exposed as expected.

If the sysfs values are correct but Waybar still shows nothing, investigate the Waybar configuration and logs before modifying the driver.

## Troubleshooting

### The build fails

- Check that the kernel build tree exists.
- Confirm the headers match the intended kernel.
- Read the first compiler error rather than only the final `make` failure.
- Inspect recent source changes.
- Run `make clean` before rebuilding when appropriate.

### The USB device is missing

- Confirm that the receiver is connected.
- Check `lsusb`.
- Try another USB port if appropriate.
- Inspect kernel logs.
- Confirm the source includes the intended USB ID.

### The module fails to load

- Check that it was built for the active kernel.
- Inspect `modinfo` and the module's `vermagic`.
- Check kernel logs for symbol, signing, or probe errors.
- Verify Secure Boot and module-signing requirements.
- Check whether the target interface is already claimed by another driver.

### The power supply is missing

- Verify that the module loaded.
- Check for HID probe and power supply registration errors.
- Confirm that the intended USB interface matches the driver.
- Check that the module was installed for the active kernel.

### The battery percentage is incorrect

- Inspect the raw values exposed by the driver.
- Verify the expected report-field interpretation.
- Check the device state and reconnect the receiver.
- Compare the reading with a known device state before changing parsing logic.

### The charging icon is incorrect

- Inspect the power supply `status` and `online` properties.
- Review the wired-mode and charging-state logic.
- Do not assume that wired mode and charging state are interchangeable.
- Test changes against actual hardware before relying on them.

### The module disappears after a kernel upgrade

Out-of-tree modules may need to be rebuilt for a new kernel version.

Rebuild against the new kernel's matching headers, install the resulting module for that version, refresh module metadata, and verify the resolved module path before loading it.

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

- Preserve the original author's copyright and SPDX identifier.
- Keep a known-good copy of the source.
- Document the reason for each change.
- Build against the intended kernel.
- Inspect the module's logs and power supply values.
- Test wireless and wired operation separately where applicable.
- Verify Waybar behavior independently from driver behavior.
- Avoid committing compiled kernel modules or unrelated machine configuration.

Changes to `ONLINE`, charging status, report parsing, polling, and interface matching should be accompanied by explicit hardware-test results.

## Known Limitations

- The target receiver's complete hardware compatibility has not been independently established.
- Battery report interpretation is based on the recovered implementation.
- Kernel compatibility must be verified for each target version.
- Battery readings may be stale or unavailable when the receiver or mouse is asleep or disconnected.
- Wired-mode and charging semantics require hardware verification.
- There is no verified automated installer or DKMS workflow in the current repository.
- Other Kysona products and similar receivers are not guaranteed to work.
- Runtime testing is required before treating the driver as reliable.

## Security and Reliability

Kernel modules execute with kernel-level privileges. Only build and load source you trust.

Before testing:

- Review changes to the driver source.
- Keep a working kernel available.
- Avoid loading modules compiled for an incompatible kernel.
- Do not unbind unrelated HID interfaces.
- Do not commit OAuth tokens, passwords, private keys, or other secrets.
- Keep logs focused on relevant driver diagnostics.

This project is provided for development and hardware experimentation. It is not a substitute for careful kernel-level testing.

## Contributing

Bug reports, build fixes, documentation improvements, and verified hardware observations are welcome.

When reporting a problem, include:

- Distribution and kernel version.
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

The original copyright notice and license identifier must remain intact. Before redistributing the source, verify its provenance and applicable license terms, and include any required license text or notices.

Hardware-specific adaptations, testing results, and documentation changes should be clearly distinguished from the original author's work.

---

**Repository:** [nebularch/cx-kysona-battery](https://github.com/nebularch/cx-kysona-battery)

The repository link assumes the project is published under that name. Until the repository exists, the link will not resolve.
