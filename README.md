# Specfiles for MinIO Server, Client, and Console

![Release Status](https://img.shields.io/badge/status-production-green.svg)
[![License](https://img.shields.io/badge/License-MPL--2.0-blue.svg)](https://spdx.org/licenses/MPL-2.0.html)

[![MinIO](https://raw.githubusercontent.com/minio/minio/master/.github/logo.svg?sanitize=true)](https://min.io)

MinIO is an open source, S3 compatible, enterprise hardened and high performance distributed object storage system.
* Official Site: https://min.io
* GitHub Sites:
  * https://github.com/minio/minio
  * https://github.com/minio/mc
  * https://github.com/minio/object-browser

This repository contains RPM *specfile*s for building MinIO server, client (mc), and console (object-browser) from source.

Since MinIO no longer provides pre-built binaries, these specfiles allow you to build your own RPM packages from source with the latest releases.

## Versions

| Package | Version | Commit | Release Date |
|---------|---------|--------|--------------|
| MinIO Server | RELEASE.2025-10-15T17-29-55Z | 9e49d5e7 | 2025-10-15 |
| MinIO Client (mc) | RELEASE.2025-08-13T08-35-41Z | 7394ce0d | 2025-08-13 |
| MinIO Console | v1.7.6 | f4a08fc0 | Pre-feature-removal version |

## Features

- ✅ **Custom Branding**: Optionally customize the release tag prefix (e.g., for internal builds)
- ✅ **Latest Releases**: Updated to most recent stable versions
- ✅ **Systemd Integration**: Uses official MinIO systemd unit files
- ✅ **Standard Paths**: `/etc/default/` for configs, `minio-user` for service account
- ✅ **Security Fixes**: Includes critical security patches
- ✅ **Automated Scripts**: Build automation and update checking included

## Usage

### Prerequisites

```bash
sudo dnf install -y rpm-build golang git nodejs make
```

**Note**:
- Git 2.x is required
- Node.js 18+ is required for building MinIO Console
- Go 1.7+ is required

### Build Instructions

#### Automated Build (Recommended)

The easiest way to build all three packages is using the automated build script:

```bash
# Build all packages with default RELEASE prefix
./build-all.sh

# Build with custom branding
./build-all.sh SONIC

# Build without checking RPM dependencies (useful on Ubuntu/Debian)
./build-all.sh RELEASE --nodeps
```

The script will:
- Check for prerequisites (go, npm, yarn, rpmbuild)
- Download source tarballs from GitHub
- Build all three RPM packages
- Display a summary with installation instructions

#### Manual Build

If you prefer to build packages individually:

##### Setup Build Environment

```bash
mkdir -p ~/rpmbuild/{SPECS,SOURCES}
```

##### MinIO Server

```bash
# Copy spec and source files
cp minio.spec ~/rpmbuild/SPECS/
cp minio.service minio.conf ~/rpmbuild/SOURCES/

# Download source tarball
curl -L https://github.com/minio/minio/archive/RELEASE.2025-10-15T17-29-55Z.tar.gz \
    -o ~/rpmbuild/SOURCES/RELEASE.2025-10-15T17-29-55Z.tar.gz

# Build (uses RELEASE prefix by default)
rpmbuild -ba ~/rpmbuild/SPECS/minio.spec

# Or build with custom branding for internal use
rpmbuild -ba --define 'release_prefix CUSTOM' ~/rpmbuild/SPECS/minio.spec
```

**Result**: Binary installed to `/usr/sbin/minio`

#### MinIO Client (mc)

```bash
# Copy spec file
cp minio-mc.spec ~/rpmbuild/SPECS/

# Download source tarball
curl -L https://github.com/minio/mc/archive/RELEASE.2025-08-13T08-35-41Z.tar.gz \
    -o ~/rpmbuild/SOURCES/RELEASE.2025-08-13T08-35-41Z.tar.gz

# Build (uses RELEASE prefix by default)
rpmbuild -ba ~/rpmbuild/SPECS/minio-mc.spec

# Or build with custom branding for internal use
rpmbuild -ba --define 'release_prefix CUSTOM' ~/rpmbuild/SPECS/minio-mc.spec
```

**Result**: Binary installed to `/usr/bin/mcli`

#### MinIO Console (Object Browser)

```bash
# Copy spec file
cp minio-console.spec ~/rpmbuild/SPECS/

# Download source tarball
curl -L https://github.com/minio/object-browser/archive/refs/tags/v1.7.6.tar.gz \
    -o ~/rpmbuild/SOURCES/v1.7.6.tar.gz

# Build (uses RELEASE prefix by default)
rpmbuild -ba ~/rpmbuild/SPECS/minio-console.spec

# Or build with custom branding for internal use
rpmbuild -ba --define 'release_prefix CUSTOM' ~/rpmbuild/SPECS/minio-console.spec
```

**Result**: Binary installed to `/usr/bin/minio-console`

**Note**: This uses v1.7.6 from object-browser, the last version before features were removed in the community edition.

### Installation

Install the resulting RPM packages:

```bash
sudo dnf install ~/rpmbuild/RPMS/x86_64/minio-*.rpm
sudo dnf install ~/rpmbuild/RPMS/x86_64/mcli-*.rpm
sudo dnf install ~/rpmbuild/RPMS/x86_64/minio-console-*.rpm
```

### Configuration

#### MinIO Server

1. **Configure volumes** in `/etc/default/minio`:
   ```bash
   MINIO_VOLUMES="/data"
   MINIO_OPTS=""
   ```

2. **Set credentials** via systemd override (more secure than environment file):
   ```bash
   sudo mkdir -p /etc/systemd/system/minio.service.d
   sudo tee /etc/systemd/system/minio.service.d/credentials.conf <<EOF
   [Service]
   Environment=MINIO_ROOT_USER=admin
   Environment=MINIO_ROOT_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 32)
   EOF
   sudo chmod 600 /etc/systemd/system/minio.service.d/credentials.conf
   ```

3. **Create data directory**:
   ```bash
   sudo mkdir -p /data
   sudo chown minio-user:minio-user /data
   ```

4. **Start the service**:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now minio.service
   sudo systemctl status minio.service
   ```

#### MinIO Console

1. **Configure console** in `/etc/default/minio-console`:
   ```bash
   CONSOLE_OPTS="--address :9090 --console-minio-server http://127.0.0.1:9000"
   ```

2. **Start the service**:
   ```bash
   sudo systemctl enable --now minio-console.service
   sudo systemctl status minio-console.service
   ```

Access the web UI at `http://your-server:9090`

## Custom Release Branding

These specfiles support custom release tag prefixes for internal or organizational builds:

```bash
# Build with custom branding
rpmbuild -ba --define 'release_prefix MYORG' ~/rpmbuild/SPECS/minio.spec

# Verify the version
minio --version
# Output: minio version MYORG.2025-10-15T17-29-55Z (commit-id=9e49d5e7...)
```

The `release_prefix` variable defaults to `RELEASE` and can be set to any value (e.g., INTERNAL, STAGING, PRODUCTION, etc.).

## Checking for Updates

Use the included update checker script to see if newer versions are available:

```bash
# Check for updates
./check-updates.sh

# Automatically update spec files to latest versions
./check-updates.sh --update
```

The script will:
- Query GitHub API for the latest release tags
- Compare with versions in your spec files
- Show what updates are available
- Optionally update the spec files with new versions and commit IDs

## Key Changes from Original Specfiles

- ✅ Updated MinIO server to RELEASE.2025-10-15T17-29-55Z (from 2020)
- ✅ Updated MinIO client to RELEASE.2025-08-13T08-35-41Z (from 2020)
- ✅ Added MinIO Console (object-browser v1.7.6)
- ✅ Changed service user from `minio` to `minio-user` (matches official MinIO)
- ✅ Changed config location from `/etc/sysconfig` to `/etc/default` (matches official MinIO)
- ✅ Updated systemd service file to match official MinIO service
- ✅ Changed variable names: `MINIO_OPTIONS` → `MINIO_OPTS`
- ✅ Renamed package and binary from `mc` to `mcli` (matches official naming, avoids Midnight Commander conflict)
- ✅ Added configurable release prefix for custom branding

## Security

For production deployments:

1. **Use TLS/SSL**: Configure certificates in `/var/lib/minio/.minio/certs/`
2. **Strong Credentials**: Use long, random passwords for MINIO_ROOT_USER/PASSWORD
3. **Firewall**: Restrict access to ports 9000 (S3 API) and 9090 (Console)
4. **Updates**: Regularly update to latest releases for security patches

See the official documentation:
 * https://docs.min.io/
 * https://min.io/docs/minio/linux/operations/network-encryption.html

## License

MinIO software is licensed under GNU AGPLv3.

These spec files are provided as-is for building MinIO from source.
