#!/bin/bash
# Generic ZFS package update script
# Supports both zfs-linux-zen and zfs-utils packages

set -euo pipefail

# Get package type from environment or parameter
PACKAGE_TYPE="${1:-${PACKAGE_TYPE:-auto}}"
PKGBUILD_PATH="${PKGBUILD_PATH:-./PKGBUILD}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# Auto-detect package type from PKGBUILD
detect_package_type() {
    if grep -q 'pkgbase="zfs-linux-zen"' "$PKGBUILD_PATH" 2>/dev/null; then
        echo "zfs-linux-zen"
    elif grep -q 'pkgname.*zfs-utils' "$PKGBUILD_PATH" 2>/dev/null; then
        echo "zfs-utils"
    else
        log_error "Cannot detect package type from PKGBUILD"
        return 1
    fi
}

# Get current ZFS version from PKGBUILD
get_current_zfs_version() {
    if grep -q '_zfsver=' "$PKGBUILD_PATH"; then
        grep -oP '_zfsver="\K[^"]+' "$PKGBUILD_PATH"
    elif grep -q 'pkgver=' "$PKGBUILD_PATH"; then
        grep -oP '^pkgver=\K[^[:space:]]+' "$PKGBUILD_PATH"
    else
        log_error "Cannot find ZFS version in PKGBUILD"
        return 1
    fi
}

# Get current kernel version from PKGBUILD (zfs-linux-zen only)
get_current_kernel_version() {
    grep -oP '_kernelver="\K[^"]+' "$PKGBUILD_PATH" 2>/dev/null || echo ""
}

# Get latest linux-zen kernel version from Arch repos
get_latest_kernel_version() {
    local response
    response=$(curl -s 'https://archlinux.org/packages/extra/x86_64/linux-zen/json/')

    if [ -z "$response" ]; then
        log_error "Failed to fetch kernel version from Arch repos"
        return 1
    fi

    local pkgver pkgrel
    pkgver=$(echo "$response" | jq -r '.pkgver')
    pkgrel=$(echo "$response" | jq -r '.pkgrel')

    if [ "$pkgver" = "null" ] || [ "$pkgrel" = "null" ]; then
        log_error "Failed to parse kernel version"
        return 1
    fi

    echo "${pkgver}-${pkgrel}"
}

# Get latest OpenZFS release from GitHub
get_latest_zfs_version() {
    local response
    response=$(curl -s 'https://api.github.com/repos/openzfs/zfs/releases/latest')

    if [ -z "$response" ]; then
        log_error "Failed to fetch ZFS version from GitHub"
        return 1
    fi

    local version
    version=$(echo "$response" | jq -r '.tag_name' | sed 's/^zfs-//')

    if [ "$version" = "null" ] || [ -z "$version" ]; then
        log_error "Failed to parse ZFS version"
        return 1
    fi

    echo "$version"
}

# Download ZFS tarball and calculate sha256sum
get_zfs_sha256() {
    local version="$1"
    local url="https://github.com/openzfs/zfs/releases/download/zfs-${version}/zfs-${version}.tar.gz"
    local tmp_file
    tmp_file=$(mktemp)

    if ! curl -L -s -o "$tmp_file" "$url"; then
        log_error "Failed to download ZFS tarball"
        rm -f "$tmp_file"
        return 1
    fi

    local checksum
    checksum=$(sha256sum "$tmp_file" | awk '{print $1}')
    rm -f "$tmp_file"

    echo "$checksum"
}

# Update PKGBUILD for zfs-linux-zen package
update_pkgbuild_zen() {
    local new_zfs_version="$1"
    local new_kernel_version="$2"
    local new_sha256="$3"

    log_info "Updating PKGBUILD (zfs-linux-zen)..."

    cp "$PKGBUILD_PATH" "${PKGBUILD_PATH}.bak"

    sed -i "s/_zfsver=\"[^\"]*\"/_zfsver=\"${new_zfs_version}\"/" "$PKGBUILD_PATH"
    sed -i "s/_kernelver=\"[^\"]*\"/_kernelver=\"${new_kernel_version}\"/" "$PKGBUILD_PATH"
    sed -i "s/_kernelver_full=\"[^\"]*\"/_kernelver_full=\"${new_kernel_version}\"/" "$PKGBUILD_PATH"
    sed -i "s/sha256sums=(\"[^\"]*\")/sha256sums=(\"${new_sha256}\")/" "$PKGBUILD_PATH"
    sed -i "s/pkgrel=.*/pkgrel=1/" "$PKGBUILD_PATH"

    log_info "PKGBUILD updated successfully"
}

# Update PKGBUILD for zfs-utils package
update_pkgbuild_utils() {
    local new_zfs_version="$1"
    local new_sha256="$2"

    log_info "Updating PKGBUILD (zfs-utils)..."

    cp "$PKGBUILD_PATH" "${PKGBUILD_PATH}.bak"

    # Update version variable (could be pkgver or _zfsver)
    if grep -q '_zfsver=' "$PKGBUILD_PATH"; then
        sed -i "s/_zfsver=\"[^\"]*\"/_zfsver=\"${new_zfs_version}\"/" "$PKGBUILD_PATH"
    else
        sed -i "s/^pkgver=.*/pkgver=${new_zfs_version}/" "$PKGBUILD_PATH"
    fi

    # Update checksum - handle both single and multi-line arrays
    # For single-line arrays: sha256sums=("checksum")
    # For multi-line arrays: sha256sums=('checksum1'
    #                                     'checksum2'...)
    # We need to replace only the first checksum (ZFS tarball)

    if grep -q "sha256sums=(" "$PKGBUILD_PATH"; then
        # Check if it's a single-line array with double quotes
        if grep -q 'sha256sums=(".*")' "$PKGBUILD_PATH"; then
            # Single checksum on one line with double quotes
            sed -i "s/sha256sums=(\"[^\"]*\")/sha256sums=(\"${new_sha256}\")/" "$PKGBUILD_PATH"
        elif grep -q "sha256sums=('[^']*'" "$PKGBUILD_PATH"; then
            # Multi-line array with single quotes - first checksum on same line as sha256sums=(
            # Match sha256sums=('old_checksum' and replace just the checksum part
            sed -i "s/sha256sums=('[^']*'/sha256sums=('${new_sha256}'/" "$PKGBUILD_PATH"
        else
            log_warn "Unable to detect sha256sums format - may need manual update"
        fi
    fi

    sed -i "s/^pkgrel=.*/pkgrel=1/" "$PKGBUILD_PATH"

    log_info "PKGBUILD updated successfully"
}

# Generate .SRCINFO
generate_srcinfo() {
    log_info "Generating .SRCINFO..."

    if ! command -v makepkg &> /dev/null; then
        log_warn "makepkg not found, cannot generate .SRCINFO"
        log_warn "You may need to install pacman/makepkg or generate .SRCINFO manually"
        return 0
    fi

    makepkg --printsrcinfo > .SRCINFO
    log_info ".SRCINFO generated successfully"
}

# Main update logic for zfs-linux-zen
update_zen_package() {
    log_info "Updating zfs-linux-zen package..."

    local current_zfs current_kernel
    current_zfs=$(get_current_zfs_version)
    current_kernel=$(get_current_kernel_version)

    log_info "Current ZFS version: $current_zfs"
    log_info "Current kernel version: $current_kernel"

    log_info "Checking for latest versions..."
    local latest_zfs latest_kernel
    latest_zfs=$(get_latest_zfs_version)
    latest_kernel=$(get_latest_kernel_version)

    log_info "Latest ZFS version: $latest_zfs"
    log_info "Latest kernel version: $latest_kernel"

    # Check if update is needed
    local needs_update=false
    local update_reason=""

    if [ "$current_zfs" != "$latest_zfs" ]; then
        needs_update=true
        update_reason="ZFS: $current_zfs → $latest_zfs"
    fi

    if [ "$current_kernel" != "$latest_kernel" ]; then
        if [ "$needs_update" = true ]; then
            update_reason="$update_reason, Kernel: $current_kernel → $latest_kernel"
        else
            update_reason="Kernel: $current_kernel → $latest_kernel"
        fi
        needs_update=true
    fi

    # Check if force update is requested
    local force_update="${FORCE_UPDATE:-false}"

    if [ "$needs_update" = false ] && [ "$force_update" != "true" ]; then
        log_info "Package is up to date!"
        echo "up_to_date=true" >> "${GITHUB_OUTPUT:-/dev/null}" 2>/dev/null || true
        return 0
    fi

    if [ "$needs_update" = false ] && [ "$force_update" = "true" ]; then
        log_info "Force update requested - incrementing pkgrel..."
        update_reason="Forced rebuild (no version change)"
        needs_update=true

        # Get current pkgrel and increment it
        local current_pkgrel
        current_pkgrel=$(grep -oP '^pkgrel=\K[0-9]+' "$PKGBUILD_PATH")
        local new_pkgrel=$((current_pkgrel + 1))

        sed -i "s/^pkgrel=.*/pkgrel=${new_pkgrel}/" "$PKGBUILD_PATH"
        generate_srcinfo

        # Output for GitHub Actions
        if [ -n "${GITHUB_OUTPUT:-}" ]; then
            echo "updated=true" >> "$GITHUB_OUTPUT"
            echo "zfs_version=$current_zfs" >> "$GITHUB_OUTPUT"
            echo "kernel_version=$current_kernel" >> "$GITHUB_OUTPUT"
            echo "update_reason=$update_reason (pkgrel: $current_pkgrel → $new_pkgrel)" >> "$GITHUB_OUTPUT"
        fi

        log_info "Update completed successfully!"
        log_info "Update summary: $update_reason (pkgrel: $current_pkgrel → $new_pkgrel)"
        return 0
    fi

    log_info "Update needed: $update_reason"

    # Get new checksum if ZFS version changed
    local new_sha256
    if [ "$current_zfs" != "$latest_zfs" ]; then
        log_info "Downloading ZFS ${latest_zfs} tarball to calculate checksum..."
        new_sha256=$(get_zfs_sha256 "$latest_zfs")
        log_info "New SHA256: $new_sha256"
    else
        new_sha256=$(grep -oP 'sha256sums=\("\K[^"]+' "$PKGBUILD_PATH")
    fi

    update_pkgbuild_zen "$latest_zfs" "$latest_kernel" "$new_sha256"
    generate_srcinfo

    # Output for GitHub Actions
    if [ -n "${GITHUB_OUTPUT:-}" ]; then
        echo "updated=true" >> "$GITHUB_OUTPUT"
        echo "zfs_version=$latest_zfs" >> "$GITHUB_OUTPUT"
        echo "kernel_version=$latest_kernel" >> "$GITHUB_OUTPUT"
        echo "update_reason=$update_reason" >> "$GITHUB_OUTPUT"
    fi

    log_info "Update completed successfully!"
    log_info "Update summary: $update_reason"
}

# Main update logic for zfs-utils
update_utils_package() {
    log_info "Updating zfs-utils package..."

    local current_zfs
    current_zfs=$(get_current_zfs_version)

    log_info "Current ZFS version: $current_zfs"

    log_info "Checking for latest version..."
    local latest_zfs
    latest_zfs=$(get_latest_zfs_version)

    log_info "Latest ZFS version: $latest_zfs"

    # Check if force update is requested
    local force_update="${FORCE_UPDATE:-false}"

    if [ "$current_zfs" = "$latest_zfs" ] && [ "$force_update" != "true" ]; then
        log_info "Package is up to date!"
        echo "up_to_date=true" >> "${GITHUB_OUTPUT:-/dev/null}" 2>/dev/null || true
        return 0
    fi

    if [ "$current_zfs" = "$latest_zfs" ] && [ "$force_update" = "true" ]; then
        log_info "Force update requested - incrementing pkgrel..."
        local update_reason="Forced rebuild (no version change)"

        # Get current pkgrel and increment it
        local current_pkgrel
        current_pkgrel=$(grep -oP '^pkgrel=\K[0-9]+' "$PKGBUILD_PATH")
        local new_pkgrel=$((current_pkgrel + 1))

        sed -i "s/^pkgrel=.*/pkgrel=${new_pkgrel}/" "$PKGBUILD_PATH"
        generate_srcinfo

        # Output for GitHub Actions
        if [ -n "${GITHUB_OUTPUT:-}" ]; then
            echo "updated=true" >> "$GITHUB_OUTPUT"
            echo "zfs_version=$current_zfs" >> "$GITHUB_OUTPUT"
            echo "update_reason=$update_reason (pkgrel: $current_pkgrel → $new_pkgrel)" >> "$GITHUB_OUTPUT"
        fi

        log_info "Update completed successfully!"
        log_info "Update summary: $update_reason (pkgrel: $current_pkgrel → $new_pkgrel)"
        return 0
    fi

    local update_reason="ZFS: $current_zfs → $latest_zfs"
    log_info "Update needed: $update_reason"

    log_info "Downloading ZFS ${latest_zfs} tarball to calculate checksum..."
    local new_sha256
    new_sha256=$(get_zfs_sha256 "$latest_zfs")
    log_info "New SHA256: $new_sha256"

    update_pkgbuild_utils "$latest_zfs" "$new_sha256"
    generate_srcinfo

    # Output for GitHub Actions
    if [ -n "${GITHUB_OUTPUT:-}" ]; then
        echo "updated=true" >> "$GITHUB_OUTPUT"
        echo "zfs_version=$latest_zfs" >> "$GITHUB_OUTPUT"
        echo "update_reason=$update_reason" >> "$GITHUB_OUTPUT"
    fi

    log_info "Update completed successfully!"
    log_info "Update summary: $update_reason"
}

# Main entry point
main() {
    log_info "Starting ZFS package update check..."

    # Detect or use specified package type
    if [ "$PACKAGE_TYPE" = "auto" ]; then
        PACKAGE_TYPE=$(detect_package_type)
        log_info "Auto-detected package type: $PACKAGE_TYPE"
    else
        log_info "Using specified package type: $PACKAGE_TYPE"
    fi

    case "$PACKAGE_TYPE" in
        zfs-linux-zen)
            update_zen_package
            ;;
        zfs-utils)
            update_utils_package
            ;;
        *)
            log_error "Unknown package type: $PACKAGE_TYPE"
            log_error "Supported types: zfs-linux-zen, zfs-utils"
            return 1
            ;;
    esac
}

main "$@"
