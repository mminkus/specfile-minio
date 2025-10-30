#!/bin/bash
# Check for new MinIO releases and compare with current spec files
# Usage: ./check-updates.sh [--update-specs]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATE_SPECS=false

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [[ "$1" == "--update-specs" ]]; then
    UPDATE_SPECS=true
fi

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_update() {
    echo -e "${BLUE}[UPDATE]${NC} $1"
}

# Function to get latest release tag from GitHub
get_latest_release() {
    local repo=$1
    local filter=${2:-"RELEASE"}

    # Get latest release tag matching the filter pattern
    curl -s "https://api.github.com/repos/${repo}/tags" | \
        grep '"name":' | \
        grep "${filter}" | \
        head -n 1 | \
        sed -E 's/.*"([^"]+)".*/\1/'
}

# Function to get commit ID for a tag
get_commit_id() {
    local repo=$1
    local tag=$2

    git ls-remote --tags "https://github.com/${repo}.git" | \
        grep "refs/tags/${tag}^{}" | \
        awk '{print $1}'
}

# Function to extract version from spec file
get_spec_version() {
    local spec_file=$1
    grep "^%global tag" "$spec_file" | awk '{print $3}'
}

# Function to extract commit from spec file
get_spec_commit() {
    local spec_file=$1
    grep "^%global commitid" "$spec_file" | awk '{print $3}'
}

# Function to update spec file
update_spec_file() {
    local spec_file=$1
    local old_tag=$2
    local new_tag=$3
    local old_commit=$4
    local new_commit=$5

    if [[ "$UPDATE_SPECS" == true ]]; then
        log_update "Updating ${spec_file}..."
        sed -i "s|^%global tag ${old_tag}|%global tag ${new_tag}|" "$spec_file"
        sed -i "s|^%global commitid ${old_commit}|%global commitid ${new_commit}|" "$spec_file"
        log_info "✓ Updated ${spec_file}"
    else
        log_warn "Run with --update-specs to automatically update spec files"
    fi
}

echo ""
log_info "===== Checking for MinIO Updates ====="
echo ""

#
# Check MinIO Server
#
log_info "Checking MinIO Server..."
MINIO_SPEC="${SCRIPT_DIR}/minio.spec"
CURRENT_MINIO_TAG=$(get_spec_version "$MINIO_SPEC")
CURRENT_MINIO_COMMIT=$(get_spec_commit "$MINIO_SPEC")
LATEST_MINIO_TAG=$(get_latest_release "minio/minio" "RELEASE")

echo "  Current: ${CURRENT_MINIO_TAG} (${CURRENT_MINIO_COMMIT:0:8})"
echo "  Latest:  ${LATEST_MINIO_TAG}"

if [[ "$CURRENT_MINIO_TAG" != "$LATEST_MINIO_TAG" ]]; then
    log_warn "⚠ New MinIO server version available!"
    LATEST_MINIO_COMMIT=$(get_commit_id "minio/minio" "$LATEST_MINIO_TAG")
    echo "  New commit: ${LATEST_MINIO_COMMIT:0:8}"
    update_spec_file "$MINIO_SPEC" "$CURRENT_MINIO_TAG" "$LATEST_MINIO_TAG" \
        "$CURRENT_MINIO_COMMIT" "$LATEST_MINIO_COMMIT"
else
    log_info "✓ MinIO server is up to date"
fi
echo ""

#
# Check MinIO Client (mc)
#
log_info "Checking MinIO Client (mc)..."
MC_SPEC="${SCRIPT_DIR}/minio-mc.spec"
CURRENT_MC_TAG=$(get_spec_version "$MC_SPEC")
CURRENT_MC_COMMIT=$(get_spec_commit "$MC_SPEC")
LATEST_MC_TAG=$(get_latest_release "minio/mc" "RELEASE")

echo "  Current: ${CURRENT_MC_TAG} (${CURRENT_MC_COMMIT:0:8})"
echo "  Latest:  ${LATEST_MC_TAG}"

if [[ "$CURRENT_MC_TAG" != "$LATEST_MC_TAG" ]]; then
    log_warn "⚠ New MinIO client version available!"
    LATEST_MC_COMMIT=$(get_commit_id "minio/mc" "$LATEST_MC_TAG")
    echo "  New commit: ${LATEST_MC_COMMIT:0:8}"
    update_spec_file "$MC_SPEC" "$CURRENT_MC_TAG" "$LATEST_MC_TAG" \
        "$CURRENT_MC_COMMIT" "$LATEST_MC_COMMIT"
else
    log_info "✓ MinIO client is up to date"
fi
echo ""

#
# MinIO Console - no check needed
#
log_info "Checking MinIO Console..."
CONSOLE_SPEC="${SCRIPT_DIR}/minio-console.spec"
CURRENT_CONSOLE_TAG=$(get_spec_version "$CONSOLE_SPEC")
echo "  Current: ${CURRENT_CONSOLE_TAG}"
log_info "ℹ Staying at v1.7.6 (last version before feature removal)"
echo ""

#
# Summary
#
log_info "===== Summary ====="
if [[ "$CURRENT_MINIO_TAG" != "$LATEST_MINIO_TAG" ]] || [[ "$CURRENT_MC_TAG" != "$LATEST_MC_TAG" ]]; then
    if [[ "$UPDATE_SPECS" == true ]]; then
        echo ""
        log_update "Spec files have been updated!"
        log_info "Review the changes with: git diff"
        log_info "Update changelogs as needed"
        log_info "Build new RPMs with: ./build-all.sh"
    else
        echo ""
        log_warn "Updates are available!"
        log_info "Run './check-updates.sh --update-specs' to automatically update spec files"
    fi
else
    echo ""
    log_info "All packages are up to date!"
fi
echo ""
