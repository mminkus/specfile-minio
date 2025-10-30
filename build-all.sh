#!/bin/bash
# Build script for MinIO Server, Client, and Console RPMs
# Usage: ./build-all.sh [RELEASE_PREFIX] [--no-deps]
# Example: ./build-all.sh MYORG
# Example: ./build-all.sh MYORG --no-deps  (for Ubuntu/Debian builds)

set -e

# Configuration
RPMBUILD_DIR="${HOME}/rpmbuild"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Parse command line arguments
RELEASE_PREFIX="${1:-RELEASE}"
RPMBUILD_OPTS=""

# Check for --no-deps flag (useful for Ubuntu/Debian where BuildRequires don't work)
if [[ "$2" == "--no-deps" ]] || [[ "$1" == "--no-deps" ]]; then
    RPMBUILD_OPTS="--nodeps"
    log_warn "Building with --nodeps (skipping dependency checks)"
    if [[ "$1" == "--no-deps" ]]; then
        RELEASE_PREFIX="RELEASE"
    fi
fi

# Check prerequisites
log_info "Checking prerequisites..."
for cmd in rpmbuild curl make npm; do
    if ! command -v $cmd &> /dev/null; then
        log_error "$cmd is not installed. Please install it first."
        exit 1
    fi
done

# Check for Go (might be 'go' not 'golang')
if ! command -v go &> /dev/null; then
    log_error "go is not installed. Please install it first."
    exit 1
fi

# Check for yarn (or install via corepack)
if ! command -v yarn &> /dev/null; then
    log_error "yarn is not installed. Please install it using these commands:"
    echo ""
    echo "  npm install -g corepack"
    echo "  corepack enable"
    echo "  corepack prepare yarn@4.4.0 --activate"
    echo ""
    echo "If you don't have npm global install permissions, ask your admin to run:"
    echo "  sudo npm install -g corepack"
    echo ""
    exit 1
fi

# Setup build environment
log_info "Setting up build environment..."
mkdir -p "${RPMBUILD_DIR}"/{SPECS,SOURCES,RPMS,SRPMS,BUILD}

# Define versions (from spec files)
MINIO_VERSION="RELEASE.2025-10-15T17-29-55Z"
MC_VERSION="RELEASE.2025-08-13T08-35-41Z"
CONSOLE_VERSION="v1.7.6"

log_info "Building with release prefix: ${RELEASE_PREFIX}"
echo ""

#
# Build MinIO Server
#
log_info "===== Building MinIO Server ====="
log_info "Copying spec and config files..."
cp "${SCRIPT_DIR}/minio.spec" "${RPMBUILD_DIR}/SPECS/"
cp "${SCRIPT_DIR}/minio.service" "${RPMBUILD_DIR}/SOURCES/"
cp "${SCRIPT_DIR}/minio.conf" "${RPMBUILD_DIR}/SOURCES/"

log_info "Downloading MinIO server source tarball..."
if [ ! -f "${RPMBUILD_DIR}/SOURCES/${MINIO_VERSION}.tar.gz" ]; then
    curl -L "https://github.com/minio/minio/archive/${MINIO_VERSION}.tar.gz" \
        -o "${RPMBUILD_DIR}/SOURCES/${MINIO_VERSION}.tar.gz"
else
    log_warn "MinIO tarball already exists, skipping download"
fi

log_info "Building MinIO server RPM..."
rpmbuild -ba ${RPMBUILD_OPTS} \
    --define "_topdir ${RPMBUILD_DIR}" \
    --define "_sourcedir ${RPMBUILD_DIR}/SOURCES" \
    --define "_specdir ${RPMBUILD_DIR}/SPECS" \
    --define "_rpmdir ${RPMBUILD_DIR}/RPMS" \
    --define "_srcrpmdir ${RPMBUILD_DIR}/SRPMS" \
    --define "release_prefix ${RELEASE_PREFIX}" \
    "${RPMBUILD_DIR}/SPECS/minio.spec"

log_info "✓ MinIO server build complete"
echo ""

#
# Build MinIO Client (mcli)
#
log_info "===== Building MinIO Client (mcli) ====="
log_info "Copying spec file..."
cp "${SCRIPT_DIR}/minio-mc.spec" "${RPMBUILD_DIR}/SPECS/"

log_info "Downloading mcli source tarball..."
if [ ! -f "${RPMBUILD_DIR}/SOURCES/${MC_VERSION}.tar.gz" ]; then
    curl -L "https://github.com/minio/mc/archive/${MC_VERSION}.tar.gz" \
        -o "${RPMBUILD_DIR}/SOURCES/${MC_VERSION}.tar.gz"
else
    log_warn "mcli tarball already exists, skipping download"
fi

log_info "Building mcli RPM..."
rpmbuild -ba ${RPMBUILD_OPTS} \
    --define "_topdir ${RPMBUILD_DIR}" \
    --define "_sourcedir ${RPMBUILD_DIR}/SOURCES" \
    --define "_specdir ${RPMBUILD_DIR}/SPECS" \
    --define "_rpmdir ${RPMBUILD_DIR}/RPMS" \
    --define "_srcrpmdir ${RPMBUILD_DIR}/SRPMS" \
    --define "release_prefix ${RELEASE_PREFIX}" \
    "${RPMBUILD_DIR}/SPECS/minio-mc.spec"

log_info "✓ MinIO client build complete"
echo ""

#
# Build MinIO Console
#
log_info "===== Building MinIO Console ====="
log_info "Copying spec and config files..."
cp "${SCRIPT_DIR}/minio-console.spec" "${RPMBUILD_DIR}/SPECS/"
cp "${SCRIPT_DIR}/minio-console.service" "${RPMBUILD_DIR}/SOURCES/"
cp "${SCRIPT_DIR}/minio-console.conf" "${RPMBUILD_DIR}/SOURCES/"

log_info "Downloading console source tarball..."
if [ ! -f "${RPMBUILD_DIR}/SOURCES/${CONSOLE_VERSION}.tar.gz" ]; then
    curl -L "https://github.com/minio/object-browser/archive/refs/tags/${CONSOLE_VERSION}.tar.gz" \
        -o "${RPMBUILD_DIR}/SOURCES/${CONSOLE_VERSION}.tar.gz"
else
    log_warn "Console tarball already exists, skipping download"
fi

log_info "Building console RPM (this may take a while due to yarn build)..."
# Set environment variable to auto-confirm corepack downloads
export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
rpmbuild -ba ${RPMBUILD_OPTS} \
    --define "_topdir ${RPMBUILD_DIR}" \
    --define "_sourcedir ${RPMBUILD_DIR}/SOURCES" \
    --define "_specdir ${RPMBUILD_DIR}/SPECS" \
    --define "_rpmdir ${RPMBUILD_DIR}/RPMS" \
    --define "_srcrpmdir ${RPMBUILD_DIR}/SRPMS" \
    --define "release_prefix ${RELEASE_PREFIX}" \
    "${RPMBUILD_DIR}/SPECS/minio-console.spec"

log_info "✓ MinIO console build complete"
echo ""

#
# Summary
#
log_info "===== Build Summary ====="
echo ""
echo "Built RPMs with release prefix: ${RELEASE_PREFIX}"
echo ""
echo "RPM packages created in: ${RPMBUILD_DIR}/RPMS/x86_64/"
ls -lh "${RPMBUILD_DIR}/RPMS/x86_64/" | grep -E "(minio|mcli)-.*\.rpm$" | tail -3
echo ""
log_info "To install:"
echo "  sudo dnf install ${RPMBUILD_DIR}/RPMS/x86_64/minio-*.rpm"
echo "  sudo dnf install ${RPMBUILD_DIR}/RPMS/x86_64/mcli-*.rpm"
echo "  sudo dnf install ${RPMBUILD_DIR}/RPMS/x86_64/minio-console-*.rpm"
echo ""
log_info "To verify versions:"
echo "  minio --version"
echo "  mcli --version"
echo "  minio-console --version"
echo ""
log_info "Version output will show: ${RELEASE_PREFIX}.YYYY-MM-DDTHH-MM-SSZ"
