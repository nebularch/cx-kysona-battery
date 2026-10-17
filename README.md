# CX Kysona Mouse Battery Driver

[![Latest Release](https://img.shields.io/github/v/release/nebularch/cx-kysona-battery)](https://github.com/nebularch/cx-kysona-battery/releases)
[![License: GPL-2.0-or-later](https://img.shields.io/badge/License-GPL--2.0--or--later-blue.svg)](LICENSE)

An out-of-tree Linux HID driver for exposing battery information from a
compatible CX/Kysona wireless mouse through the Linux power-supply subsystem.

The project targets a wireless mouse receiver identified by USB vendor/product
ID `373b:1085`. It integrates with the Linux kernel's HID and power-supply
frameworks so supported desktop utilities can read the mouse's battery level
without a separate polling application.

> **Compatibility notice:** The driver has been tested on the maintainer's
> Arch Linux system with a receiver identified as `373b:1085`. Other receivers,
> mouse revisions, kernels, and distributions may behave differently. Confirm
> that your hardware matches before installing.

## Table of contents

- [Overview](#overview)
- [Project status](#project-status)
- [Hardware compatibility](#hardware-compatibility)
- [How it works](#how-it-works)
- [Features](#features)
- [Requirements](#requirements)
- [Installation on Arch Linux](#installation-on-arch-linux)
- [Quick installation](#quick-installation)
- [Verifying the installation](#verifying-the-installation)
- [Diagnostics](#diagnostics)
- [Waybar integration](#waybar-integration)
- [Kernel updates and DKMS maintenance](#kernel-updates-and-dkms-maintenance)
- [Troubleshooting](#troubleshooting)
- [Uninstallation](#uninstallation)
- [Development and testing](#development-and-testing)
- [Security and limitations](#security-and-limitations)
- [Credits and license](#credits-and-license)

## Overview

Some wireless mice expose battery information through HID feature reports,
but their receivers may not be supported by the standard Linux HID battery
driver. Without suitable driver support, the desktop may not display the
mouse's battery percentage even though the device itself reports battery data.

This project provides a dedicated kernel HID driver for the targeted receiver.
It registers a Linux power-supply device so battery properties can be queried
through the usual sysfs interface.

The intended result is a battery reading that can be consumed by tools such as
`upower`, desktop environments, shell scripts, and Waybar.

This is a kernel driver, not a userspace daemon. It relies on the receiver's
HID protocol and the Linux kernel's device and power-supply infrastructure.

## Project status

The following reflects testing on the maintainer's system. It is not a
guarantee of compatibility with every device carrying a similar product name.

| Area | Status |
|---|---|
| Target USB ID `373b:1085` | Tested |
| DKMS build and installation | Tested on the maintainer's Arch setup |
| Module loading at startup | Configured and tested |
| HID interface binding | Tested |
| Battery power-supply registration | Tested |
| Capacity and status reporting | Tested |
| Compatibility with other receiver revisions | Not established |
| Compatibility with every kernel and distribution | Not established |

The driver should be considered hardware-specific until additional devices
and kernel versions have been tested.

## Hardware compatibility

| Property | Value |
|---|---|
| Target USB vendor/product ID | `373b:1085` |
| Driver module | `hid_kysona` |
| DKMS package name | `hid-kysona` |
| Tested power-supply name | `cx-mouse-battery` |
| Power-supply sysfs path | `/sys/class/power_supply/cx-mouse-battery` |

The USB ID identifies the receiver, not necessarily every mouse or receiver
revision sold under the same retail name. A matching USB ID is a useful
compatibility check, but it does not prove that all protocol behavior is
identical.

Check the connected USB devices with:

```bash
lsusb -nn
```

Look for:

```text
373b:1085
```

If the ID is different, do not assume this driver is compatible.

## How it works

The driver connects the receiver's HID reports to Linux's device-management
and power-supply interfaces.

At a high level:

1. **USB identification:** Linux enumerates the receiver and identifies its
   vendor and product IDs.
2. **HID binding:** The kernel matches the supported HID device to the
   `hid_kysona` driver.
3. **Device communication:** The driver communicates with the device using
   its supported HID report protocol.
4. **Power-supply registration:** The driver exposes battery properties through
   the Linux power-supply subsystem.
5. **Userspace access:** Applications read the resulting sysfs properties
   without needing to communicate with the HID device themselves.

The exposed interface follows the normal Linux power-supply model, making
battery readings available to standard tools.

This description is the driver's intended integration path; exact report
behavior and property availability depend on the connected hardware and
driver implementation.

### Why use the kernel power-supply interface?

Exposing battery information through the kernel avoids requiring a separate
userspace process to poll the receiver and maintain its own battery state.

It also makes the data easier to consume from scripts and desktop utilities
that already understand Linux power-supply devices.

## Features

On the tested setup, the driver exposes battery information through:

- **Capacity:** battery level as a percentage.
- **Status:** the reported battery state, such as `Discharging`, when provided.
- **Voltage:** a voltage reading when the driver and device expose it.

Not every property is guaranteed to be available on every compatible device.
A reported value should also be treated as the device's telemetry, not an
independent measurement of the battery's actual remaining runtime.

The driver does not promise a specific polling interval, exact remaining-time
estimate, or compatibility with every battery-monitoring application.

## Requirements

The installation instructions below target Arch Linux and use DKMS.

Install the build tools and headers for the kernel you intend to use:

```bash
sudo pacman -S --needed base-devel dkms linux-headers git
```

For a different kernel package, install its corresponding headers instead of
assuming `linux-headers` is correct. For example, systems using a separately
packaged LTS or Zen kernel need the matching header package.

Check the running kernel and available build directory:

```bash
uname -r
test -e "/usr/lib/modules/$(uname -r)/build" \
  && echo "Kernel build directory found" \
  || echo "Matching kernel headers may be missing"
```

DKMS rebuilds the module for supported installed kernels when the necessary
kernel build files are available.

## Quick installation

For Arch Linux and Arch-based systems, install the build tools, DKMS, Git,
and headers matching your running kernel.

For the standard Arch Linux kernel:

```bash
sudo pacman -S --needed base-devel dkms git linux-headers
```

For other kernels, install the matching headers instead.

Clone the repository and run the installer as your normal user:

```bash
git clone https://github.com/nebularch/cx-kysona-battery.git
cd cx-kysona-battery
./install.sh
```

Do not run the installer with `sudo`. It requests elevated privileges when
needed and checks the DKMS installation and startup configuration. It does not
force-load the driver or unbind USB interfaces.

Reboot when convenient, then check the installation and battery readings:

```bash
./scripts/check-cx-mouse-battery.sh
```

For detailed manual installation, verification, and troubleshooting, see below.

## Installation on Arch Linux

These instructions install the driver from the repository source using DKMS.
Review the commands before running them.

### 1. Obtain the source

Clone the repository:

```bash
git clone https://github.com/nebularch/cx-kysona-battery.git
cd cx-kysona-battery
```

Inspect the USB ID before proceeding:

```bash
lsusb -nn
```

Confirm that the target receiver is present as `373b:1085`.

### 2. Install the DKMS source

The DKMS source directory includes the version number. The following commands
use the package version `0.1.0`:

```bash
sudo install -d /usr/src/hid-kysona-0.1.0

sudo install -m 0644 \
  hid-kysona.c \
  Makefile \
  dkms.conf \
  /usr/src/hid-kysona-0.1.0/
```

If the repository changes its source layout or DKMS version, adjust these
commands to match the checked-out version.

### 3. Register and build the module

Register the source with DKMS, build it for the running kernel, and install it:

```bash
sudo dkms add -m hid-kysona -v 0.1.0
sudo dkms build -m hid-kysona -v 0.1.0
sudo dkms install -m hid-kysona -v 0.1.0
sudo depmod -a
```

If DKMS reports that the module or version already exists, inspect the current
DKMS state before removing or re-registering anything:

```bash
dkms status
```

Do not delete a working DKMS registration merely to retry an installation.

### 4. Configure startup loading

Create a modules-load configuration so the driver is requested at startup:

```bash
printf '%s\n' hid_kysona |
  sudo tee /etc/modules-load.d/hid_kysona.conf
```

Reboot when convenient so the module and receiver are initialized through the
normal startup sequence:

```bash
sudo reboot
```

If you do not want to reboot immediately, you can inspect the current module
and device state first. Avoid manually unbinding HID interfaces unless you
understand the effect on the mouse and keyboard interfaces.

## Verifying the installation

After rebooting, check each layer independently.

### 1. DKMS status

```bash
dkms status
```

Look for `hid-kysona/0.1.0` installed for the kernel you are using.

### 2. Module loading

```bash
lsmod | grep '^hid_kysona'
```

Check which module file is selected:

```bash
modinfo -n hid_kysona
```

If the module is loaded but the output points somewhere unexpected, inspect
the DKMS status and module paths before changing anything.

### 3. HID binding

Inspect the driver's registered HID devices:

```bash
ls -l /sys/bus/hid/drivers/kysona/
```

The directory name reflects the HID driver's registered name, which may differ
from the module filename. If it does not exist, inspect kernel messages and
the module's registration state.

### 4. Battery power supply

List the available power supplies:

```bash
ls -l /sys/class/power_supply/
```

On the tested setup, the mouse appears at:

```text
/sys/class/power_supply/cx-mouse-battery
```

Read its capacity and status:

```bash
cat /sys/class/power_supply/cx-mouse-battery/capacity
cat /sys/class/power_supply/cx-mouse-battery/status
```

If available, inspect the voltage:

```bash
cat /sys/class/power_supply/cx-mouse-battery/voltage_now
```

A missing optional property is not necessarily a driver failure. Check which
properties actually exist before diagnosing the result.

### 5. Kernel messages

Inspect messages related to the driver, HID, and DKMS:

```bash
sudo journalctl -k -b --no-pager |
  grep -iE 'kysona|373b|1085|hid|battery'
```

Look for module-loading errors, failed device probes, report errors, or
power-supply registration problems.

## Diagnostics

The repository includes a read-only diagnostic script:

```bash
./scripts/check-cx-mouse-battery.sh
```

It checks relevant installation and runtime details, including the module,
DKMS installation, selected module path, HID binding, power-supply readings,
and startup configuration.

Run it from the repository directory. If permission is denied, confirm that
the script is executable:

```bash
chmod +x scripts/check-cx-mouse-battery.sh
./scripts/check-cx-mouse-battery.sh
```

The diagnostic script is intended to inspect the system, not repair it. Review
its output before making changes.

### Interpreting the results

- **PASS:** The check found the expected state.
- **WARN:** A condition needs attention or could not be confirmed; it may not
  indicate a broken driver.
- **FAIL:** The expected condition was not found. Investigate the related
  installation or runtime layer.

Share the complete output when reporting a problem, along with the kernel
version and USB ID. Remove any unrelated sensitive information first.

## Waybar integration

Once the power-supply path exists, Waybar can display the reported percentage
using a custom module.

Add a module entry to your Waybar configuration:

```json
"custom/mouse-battery": {
  "exec": "cat /sys/class/power_supply/cx-mouse-battery/capacity",
  "interval": 30,
  "format": "󰍽 {}%",
  "tooltip": true
}
```

Add the module name to the relevant Waybar module list, for example:

```json
"modules-right": [
  "custom/mouse-battery"
]
```

Merge it into your existing list instead of replacing your current modules.
The exact configuration file and layout depend on your Waybar setup.

The `exec` command prints the capacity value, while `{}` inserts that output
into the displayed format. The `interval` controls how often Waybar runs the
command; it does not control the kernel driver's own reporting behavior.

If the power-supply path is absent, fix the driver or hardware detection
first. Waybar cannot display a value that the kernel does not expose.

## Kernel updates and DKMS maintenance

DKMS can rebuild the driver for newly installed kernels, provided the matching
headers and build tools are available.

After a kernel update, check:

```bash
uname -r
dkms status
modinfo -n hid_kysona
```

If the module is missing for the running kernel, install the matching headers
and inspect the DKMS build output before attempting a reinstall.

Review the current build logs if DKMS reports a failure. Paths can vary by
kernel and DKMS version, but the DKMS framework commonly stores build logs
under:

```text
/var/lib/dkms/hid-kysona/0.1.0/
```

For a system with multiple installed kernels, verify that the module was built
for the kernel you actually booted. A successful build for a different kernel
does not establish that the current kernel has a usable module.

Do not assume that a driver built for one kernel version is compatible with
every later kernel version.

## Troubleshooting

### The receiver is not detected

Check the USB ID:

```bash
lsusb -nn
```

If `373b:1085` is absent, check the receiver's USB connection and whether the
system detects it at all. This driver cannot make an unenumerated receiver
appear.

If a different ID appears, do not assume compatibility based only on the
product name.

### The module is not loaded

Check DKMS and the module file:

```bash
dkms status
modinfo -n hid_kysona
```

Then inspect startup configuration and kernel messages:

```bash
cat /etc/modules-load.d/hid_kysona.conf
sudo journalctl -k -b --no-pager |
  grep -iE 'kysona|hid|module|firmware'
```

Confirm that the module was built for the running kernel and that its matching
headers were installed.

### The battery power supply is missing

Check the module and HID binding before investigating userspace tools:

```bash
lsmod | grep '^hid_kysona'
ls -l /sys/bus/hid/drivers/kysona/
ls -l /sys/class/power_supply/
```

If the receiver is present but not bound to the expected driver, inspect the
kernel messages. Do not blindly unbind or rebind interfaces: a receiver can
expose multiple HID interfaces, and changing their bindings can disrupt
input devices.

### Battery readings appear stale or unexpected

Read the properties directly:

```bash
cat /sys/class/power_supply/cx-mouse-battery/capacity
cat /sys/class/power_supply/cx-mouse-battery/status
```

Check whether the value changes after using or charging the mouse, if
applicable. Hardware may update battery telemetry intermittently, and a
percentage is an estimate rather than a precise measurement of runtime.

If a property does not exist, list the directory contents before assuming
that every device must expose every property.

### The module fails after a kernel update

Confirm the running kernel and matching headers:

```bash
uname -r
pacman -Q | grep -E '^(linux|dkms|.*headers)'
dkms status
```

Review the DKMS build logs and rebuild only after confirming that the source
and kernel headers are appropriate. If the driver no longer compiles against
the new kernel, retain the build error when reporting the issue.

## Uninstallation

The following commands remove the DKMS registration and startup-loading
configuration for this version. Review the version and paths before running
them.

First, remove the module from DKMS:

```bash
sudo dkms remove -m hid-kysona -v 0.1.0 --all
```

Remove the startup-loading file:

```bash
sudo rm -f /etc/modules-load.d/hid_kysona.conf
```

Remove the installed DKMS source:

```bash
sudo rm -rf /usr/src/hid-kysona-0.1.0
```

Then reboot so the running system returns to its normal device initialization
sequence:

```bash
sudo reboot
```

If DKMS reports that the module is currently in use, do not forcefully remove
or unbind it while relying on the mouse or its receiver. Reboot first, then
complete cleanup if needed.

The commands above do not delete the cloned Git repository in your home
directory. Remove that directory separately only if you no longer need the
source or diagnostic script.

## Development and testing

Clone the repository and inspect the source before making changes:

```bash
git clone https://github.com/nebularch/cx-kysona-battery.git
cd cx-kysona-battery
git status --short --branch
```

Important files include:

| File | Purpose |
|---|---|
| `hid-kysona.c` | HID driver implementation |
| `Makefile` | Module build instructions |
| `dkms.conf` | DKMS package and build configuration |
| `scripts/check-cx-mouse-battery.sh` | Read-only installation and runtime diagnostics |
| `LICENSE` | Project license |

For development, make changes in a working copy and review the diff before
installing a new version:

```bash
git diff --check
git diff
```

Test builds against the intended kernel and verify the device behavior on
hardware that matches the target USB ID. Do not treat a successful compile as
proof that HID reports, battery values, startup loading, and cleanup all work.

When reporting a bug, include:

- The receiver's USB ID.
- The distribution and kernel version.
- The DKMS status and relevant build error, if any.
- Relevant kernel messages.
- The output of the diagnostic script.
- Which battery properties are present and whether their values change.

Do not include private credentials, access tokens, or unrelated personal data.

## Security and limitations

This project installs an out-of-tree kernel module. Kernel modules run with
high privileges, so inspect the source and understand the risks before
installing software from any repository.

Keep the source and installation instructions under review as kernels change.
A successful installation on one machine does not guarantee safety,
correctness, or compatibility on another.

Known limitations include:

- Testing is limited to the hardware and software configurations actually
  exercised by the maintainer.
- Other USB IDs and receiver revisions have not been established as supported.
- Reported battery values depend on the receiver and its firmware.
- Kernel API changes may require source updates.
- DKMS requires suitable headers and a successful build for each target kernel.
- The driver does not guarantee an exact battery-runtime estimate.

Issues and reproducible test results are welcome. Include enough technical
information to investigate the problem without exposing sensitive data.

## Credits and license

The source is based on a Kysona M600 HID driver originally attributed to
**Lode Willems (2024)**.

Please retain the original attribution and applicable license notices when
modifying or redistributing the code.

This project uses the **GNU General Public License v2.0 or later
(GPL-2.0-or-later)**. See [`LICENSE`](LICENSE) for the license text.

## Links

- [Repository](https://github.com/nebularch/cx-kysona-battery)
- [Releases](https://github.com/nebularch/cx-kysona-battery/releases)
- [Report an issue](https://github.com/nebularch/cx-kysona-battery/issues)
