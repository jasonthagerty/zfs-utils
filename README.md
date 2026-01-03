# ZFS Utils - Automated Arch Linux Package

This repository provides automatically updated ZFS userspace utilities for Arch Linux.

## Features

- **Automatic Updates**: Checks for new OpenZFS releases every 6 hours
- **Automated Building**: Builds and publishes packages automatically via GitHub Actions
- **GitHub Pages Hosting**: Packages hosted as a custom Arch repository

## Installation

### 1. Add the Repository

Add the following to `/etc/pacman.conf`:

```ini
[archzfs]
Server = https://jasonthagerty.github.io/zfs-utils/repo
SigLevel = Optional TrustAll
```

### 2. Update Package Database

```bash
sudo pacman -Sy
```

### 3. Install ZFS Utils

```bash
sudo pacman -S zfs-utils
```

## Packages Provided

- `zfs-utils` - ZFS userspace utilities and libraries

## How It Works

### Automatic Updates

The repository uses GitHub Actions to:

1. **Check for Updates** (every 6 hours):
   - Queries GitHub API for latest OpenZFS release
   - Compares with current PKGBUILD version
   - Updates PKGBUILD if new version is found

2. **Build Package** (on PKGBUILD changes):
   - Builds the package in an Arch Linux container
   - Creates repository database
   - Publishes to GitHub Pages

### Workflow Files

- `.github/workflows/auto-update.yml` - Automatic update checker (runs every 6 hours)
- `.github/workflows/manual-update.yml` - Manual update trigger
- `.github/workflows/build-and-publish.yml` - Package builder and publisher
- `.github/actions/update-zfs-package/` - Shared update action

## Repository Structure

```
zfs-utils/
├── PKGBUILD                          # Package build script
├── zfs-utils.install                 # Post-install hooks
├── zfs-utils.initcpio.hook           # Initramfs hook
├── zfs-utils.initcpio.install        # Initramfs install
├── zfs-utils.initcpio.zfsencryptssh.install
└── .github/
    ├── workflows/
    │   ├── auto-update.yml          # Automated update check
    │   ├── manual-update.yml        # Manual triggers
    │   └── build-and-publish.yml    # Build and publish
    └── actions/
        └── update-zfs-package/
            ├── action.yml            # Composite action
            └── update.sh             # Update script
```

## GitHub Pages Setup

To enable package hosting, you need to configure GitHub Pages:

1. Go to repository **Settings** → **Pages**
2. Under **Source**, select **GitHub Actions**
3. Save the settings

The first build will create the repository structure automatically.

## Manual Updates

You can manually trigger an update check:

1. Go to **Actions** tab
2. Select **Auto Update Package** workflow
3. Click **Run workflow**

Or force a package rebuild:

1. Go to **Actions** tab
2. Select **Build and Publish Package** workflow
3. Click **Run workflow**

## Development

### Testing the Update Script Locally

```bash
cd .github/actions/update-zfs-package
./update.sh
```

### Building Locally

```bash
makepkg -s
```

## Upstream

This repository is a fork of [archzfs/archzfs](https://github.com/archzfs/archzfs) with enhanced automation for faster updates.

## License

CDDL (Common Development and Distribution License) - same as ZFS

## Related Repositories

- [zfs-linux-zen](https://github.com/jasonthagerty/zfs-linux-zen) - ZFS kernel modules for linux-zen
