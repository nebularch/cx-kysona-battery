#!/usr/bin/env bash

set -u

MODULE="hid_kysona"
DKMS_MODULE="hid-kysona"
DKMS_VERSION="0.1.0"
KERNEL="$(uname -r)"
BATTERY="/sys/class/power_supply/cx-mouse-battery"
FAILURES=0
WARNINGS=0

pass() { printf '  [PASS] %s\n' "$*"; }
warn() {
    printf '  [WARN] %s\n' "$*"
    WARNINGS=$((WARNINGS + 1))
}
fail() {
    printf '  [FAIL] %s\n' "$*"
    FAILURES=$((FAILURES + 1))
}

printf '%s\n' '========================================'
printf '%s\n' ' CX/Kysona Mouse Battery Diagnostics'
printf '%s\n' '========================================'
printf 'Kernel: %s\n\n' "$KERNEL"

# 1. Check whether the module is loaded.
printf '%s\n' '1. Loaded module'
if grep -q "^${MODULE} " /proc/modules; then
    pass "$MODULE is loaded"
else
    fail "$MODULE is not loaded"
fi

# 2. Check the DKMS registration for this kernel.
printf '\n%s\n' '2. DKMS installation'
if command -v dkms >/dev/null 2>&1; then
    DKMS_RESULT="$(dkms status -m "$DKMS_MODULE" -v "$DKMS_VERSION" 2>&1 || true)"
    printf '%s\n' "${DKMS_RESULT:-No matching DKMS entry found}"

    if printf '%s\n' "$DKMS_RESULT" |
        grep -F "$KERNEL" |
        grep -q 'installed'; then
        pass "DKMS module installed for $KERNEL"
    else
        fail "DKMS does not report this version installed for $KERNEL"
    fi
else
    fail "DKMS command not found"
fi

# 3. Check which module file modprobe will select.
printf '\n%s\n' '3. Module file'
if MODULE_PATH="$(modinfo -n "$MODULE" 2>/dev/null)" &&
   [[ -f "$MODULE_PATH" ]]; then
    printf '  Path: %s\n' "$MODULE_PATH"
    if [[ "$MODULE_PATH" == *"/updates/dkms/"* ]]; then
        pass "DKMS module is selected"
    else
        warn "Selected module is not under /updates/dkms/"
    fi
else
    fail "Could not locate the module file"
fi

# 4. Check the supported mouse HID interface.
printf '\n%s\n' '4. Mouse driver binding'
FOUND_DEVICE=0

for DEVICE in /sys/bus/hid/devices/0003:373B:1085.*; do
    [[ -e "$DEVICE" ]] || continue
    FOUND_DEVICE=1

    DEVICE_NAME="${DEVICE##*/}"
    DRIVER_PATH="$(readlink -f "$DEVICE/driver" 2>/dev/null || true)"
    DRIVER_NAME="${DRIVER_PATH##*/}"

    printf '  Device: %s\n' "$DEVICE_NAME"
    if [[ "$DRIVER_NAME" == "kysona" ]]; then
        pass "Mouse interface is bound to kysona"
    elif [[ -n "$DRIVER_PATH" ]]; then
        warn "Mouse interface uses driver: $DRIVER_NAME"
    else
        warn "Mouse interface has no bound driver"
    fi
done

if [[ "$FOUND_DEVICE" -eq 0 ]]; then
    warn "USB device 373b:1085 was not found; check the dongle connection"
fi

# 5. Check the battery power supply.
printf '\n%s\n' '5. Battery reporting'
if [[ -d "$BATTERY" ]]; then
    for FIELD in capacity status voltage_now; do
        if [[ -r "$BATTERY/$FIELD" ]]; then
            printf '  %-12s %s\n' "$FIELD:" "$(cat "$BATTERY/$FIELD")"
        fi
    done
    pass "Mouse battery supply is available"
else
    fail "Battery supply not found at $BATTERY"
fi

# 6. Check startup configuration.
printf '\n%s\n' '6. Startup configuration'
if grep -Fxq "$MODULE" /etc/modules-load.d/hid_kysona.conf 2>/dev/null; then
    pass "Module is configured to load at startup"
else
    warn "Expected modules-load configuration was not found"
fi

printf '\n%s\n' '========================================'
printf 'Failures: %d | Warnings: %d\n' "$FAILURES" "$WARNINGS"

if [[ "$FAILURES" -eq 0 ]]; then
    printf '%s\n' 'Result: Core checks passed.'
else
    printf '%s\n' 'Result: Some checks need attention.'
fi

printf '%s\n' '========================================'

[[ "$FAILURES" -eq 0 ]]
