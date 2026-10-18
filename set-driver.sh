#!/usr/bin/env bash
set -Eeuo pipefail

readonly REPO_URL="https://github.com/nebularch/cx-kysona-battery.git"
readonly PROJECT_DIR="${CX_KYSONA_DIR:-$HOME/Projects/cx-kysona-battery}"

info() {
    printf '\n==> %s\n' "$*"
}

die() {
    printf '\nERROR: %s\n' "$*" >&2
    exit 1
}

[[ $EUID -ne 0 ]] ||
    die "Run this script as your normal user, without sudo."

command -v pacman >/dev/null 2>&1 ||
    die "This script requires Arch Linux or an Arch-based distribution."

command -v sudo >/dev/null 2>&1 ||
    die "Please install sudo first."

info "Installing required tools"
sudo -v
sudo pacman -S --needed base-devel dkms git curl

command -v git >/dev/null 2>&1 ||
    die "Git is unavailable."

command -v dkms >/dev/null 2>&1 ||
    die "DKMS is unavailable."

info "Checking headers for the running kernel"
KERNEL="$(uname -r)"
KERNEL_BUILD="/usr/lib/modules/$KERNEL/build"

if [[ ! -e "$KERNEL_BUILD" ]]; then
    printf 'Running kernel: %s\n' "$KERNEL"
    printf 'Missing build directory: %s\n' "$KERNEL_BUILD"
    printf 'Install the matching headers for your kernel, then rerun this script.\n'
    die "Matching kernel headers are required."
fi

info "Preparing project directory"
mkdir -p "$(dirname "$PROJECT_DIR")"

if [[ -e "$PROJECT_DIR" ]]; then
    [[ -d "$PROJECT_DIR/.git" ]] ||
        die "$PROJECT_DIR exists but is not a Git repository. Set CX_KYSONA_DIR to another directory."

    ORIGIN="$(git -C "$PROJECT_DIR" remote get-url origin)" ||
        die "Could not read the existing repository's origin."

    [[ "$ORIGIN" == "$REPO_URL" ]] ||
        die "The existing repository has a different origin: $ORIGIN"

    if [[ -n "$(git -C "$PROJECT_DIR" status --porcelain)" ]]; then
        die "Local changes or untracked files detected. Commit or back them up before updating."
    fi

    info "Updating repository (fast-forward only)"
    git -C "$PROJECT_DIR" pull --ff-only origin main
else
    info "Cloning the driver repository"
    git clone "$REPO_URL" "$PROJECT_DIR"
fi

info "Launching the driver installer"
cd "$PROJECT_DIR"

[[ -x ./install.sh ]] ||
    die "install.sh is missing or not executable."

./install.sh

info "Setup completed"
printf 'Project directory: %s\n' "$PROJECT_DIR"
printf 'After reboot, check the driver with:\n'
printf '  %s/scripts/check-cx-mouse-battery.sh\n' "$PROJECT_DIR"
