#!/usr/bin/env bash
set -Eeuo pipefail

readonly PACKAGE="hid-kysona"
readonly VERSION="0.1.0"
readonly MODULE="hid_kysona"
readonly SOURCE_DIR="/usr/src/${PACKAGE}-${VERSION}"
readonly MODULES_LOAD="/etc/modules-load.d/hid_kysona.conf"

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

info() {
    printf '\n==> %s\n' "$*"
}

command -v pacman >/dev/null 2>&1 ||
    die "This installer supports Arch Linux and Arch-based systems."

for cmd in sudo dkms make gcc cmp install grep depmod modinfo tee; do
    command -v "$cmd" >/dev/null 2>&1 ||
        die "Required command '$cmd' is missing."
done

[[ $EUID -ne 0 ]] ||
    die "Run this script as your normal user, not with sudo."

[[ -f hid-kysona.c && -f Makefile && -f dkms.conf ]] ||
    die "Run this script from the repository directory containing hid-kysona.c, Makefile and dkms.conf."

grep -q 'PACKAGE_NAME="hid-kysona"' dkms.conf ||
    die "Unexpected DKMS package name in dkms.conf."

grep -q 'PACKAGE_VERSION="0.1.0"' dkms.conf ||
    die "Unexpected DKMS version in dkms.conf."

grep -q 'BUILT_MODULE_NAME\[0\]="hid-kysona"' dkms.conf ||
    die "Unexpected built module name in dkms.conf."

readonly KERNEL="$(uname -r)"
readonly KERNEL_BUILD="/usr/lib/modules/${KERNEL}/build"

[[ -e "$KERNEL_BUILD" ]] ||
    die "Matching kernel build directory is missing: $KERNEL_BUILD. Install headers for your running kernel first."

if [[ -e "$MODULES_LOAD" ]] &&
   ! grep -Eq '^[[:space:]]*hid[-_]kysona[[:space:]]*$' "$MODULES_LOAD"; then
    die "$MODULES_LOAD exists but does not contain the expected module entry. Inspect it manually; it will not be overwritten."
fi

info "Checking privileges"
sudo -v

info "Checking DKMS source directory"
if sudo test -d "$SOURCE_DIR"; then
    for file in hid-kysona.c Makefile dkms.conf; do
        sudo cmp -s "$file" "$SOURCE_DIR/$file" ||
            die "$SOURCE_DIR/$file differs from the repository. Refusing to overwrite existing DKMS source."
    done
    info "Existing DKMS source matches this repository."
else
    info "Preparing DKMS source at $SOURCE_DIR"
    sudo install -d -m 0755 "$SOURCE_DIR"
    for file in hid-kysona.c Makefile dkms.conf; do
        sudo install -m 0644 "$file" "$SOURCE_DIR/$file"
    done
fi

info "Checking DKMS registration"
if ! STATUS="$(sudo dkms status -m "$PACKAGE" -v "$VERSION" 2>&1)"; then
    die "Could not query DKMS status: $STATUS"
fi

if [[ -z "$STATUS" ]]; then
    info "Package is not registered; adding it to DKMS."
    sudo dkms add -m "$PACKAGE" -v "$VERSION" ||
        die "DKMS registration failed."
    if ! STATUS="$(sudo dkms status -m "$PACKAGE" -v "$VERSION" 2>&1)"; then
        die "Could not verify DKMS registration: $STATUS"
    fi
fi

ARCH="$(uname -m)"

KERNEL_STATUS="$(
    printf '%s\n' "$STATUS" |
        grep -F ", ${KERNEL}, ${ARCH}: installed" || true
)"

if [[ -n "$KERNEL_STATUS" ]]; then
    info "DKMS module is already installed for kernel $KERNEL; skipping rebuild."
else
    info "Installing DKMS module for kernel $KERNEL"
    sudo dkms install -m "$PACKAGE" -v "$VERSION" -k "$KERNEL" ||
        die "DKMS installation failed for kernel $KERNEL."
fi

info "Refreshing module dependency information"
sudo depmod -a "$KERNEL"

if ! sudo test -f "$MODULES_LOAD"; then
    printf '%s\n' "$MODULE" |
        sudo tee "$MODULES_LOAD" >/dev/null
    sudo chmod 0644 "$MODULES_LOAD"
fi

info "Installation checks"
FINAL_STATUS="$(sudo dkms status -m "$PACKAGE" -v "$VERSION")" ||
    die "Could not verify final DKMS status."
printf '%s\n' "$FINAL_STATUS"

printf '%s\n' "$FINAL_STATUS" |
    grep -Fq ", ${KERNEL}, ${ARCH}: installed" ||
    die "DKMS does not report the module installed for kernel $KERNEL on architecture $ARCH."

MODULE_PATH="$(modinfo -k "$KERNEL" -n hid-kysona 2>/dev/null)" ||
    die "modinfo cannot find hid-kysona for kernel $KERNEL."

case "$MODULE_PATH" in
    */updates/dkms/*) ;;
    *) die "Module resolves to an unexpected path: $MODULE_PATH" ;;
esac

[[ -f "$MODULES_LOAD" ]] ||
    die "Startup configuration was not created: $MODULES_LOAD"

grep -Eq '^[[:space:]]*hid_kysona[[:space:]]*$' "$MODULES_LOAD" ||
    die "Startup configuration does not contain the expected hid_kysona entry."

printf '\nKernel: %s\n' "$KERNEL"
printf 'Module path: %s\n' "$MODULE_PATH"
printf 'Startup configuration: %s\n' "$MODULES_LOAD"

if [[ -d "/sys/bus/hid/drivers/kysona" ]]; then
    printf 'Driver binding directory exists.\n'
else
    printf 'Driver binding directory not present yet; a reboot may be needed.\n'
fi

printf '\nInstallation steps completed.\n'
printf 'The script did not force-load the driver or unbind any USB interface.\n'
printf 'Reboot when convenient, then run:\n'
printf '  %s/scripts/check-cx-mouse-battery.sh\n' "$PWD"
