#!/bin/bash

# Repository initialization script for Pixel 9 Pro XL (komodo) ROM development
# This script sets up the complete development environment

set -e

# Configuration
ANDROID_ROOT="$(pwd)"
DEVICE="komodo"
ANDROID_VERSION="android-16.0.0_r1"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    -b, --branch BRANCH         Android branch [default: android-16.0.0_r1]
    -d, --depth DEPTH           Clone depth for faster sync [default: 1]
    -j, --jobs JOBS             Number of parallel jobs [default: $(nproc)]
    --no-clone-bundle           Disable clone bundle for faster sync
    -h, --help                  Show this help message

Examples:
    $0                          # Initialize with defaults
    $0 -b android-15.0.0_r1     # Initialize with Android 15
    $0 -d 1 -j 8                # Shallow clone with 8 jobs

EOF
}

check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if repo is installed
    if ! command -v repo &> /dev/null; then
        error "repo tool is not installed. Please install it first:"
        error "https://source.android.com/docs/setup/develop#installing-repo"
        exit 1
    fi
    
    # Check if git is configured
    if ! git config --global user.email &> /dev/null; then
        error "Git user email is not configured. Please run:"
        error "git config --global user.email 'your-email@example.com'"
        exit 1
    fi
    
    if ! git config --global user.name &> /dev/null; then
        error "Git user name is not configured. Please run:"
        error "git config --global user.name 'Your Name'"
        exit 1
    fi
    
    # Check available disk space (minimum 400GB)
    local available_space=$(df . | awk 'NR==2 {print $4}')
    local min_space=$((400 * 1024 * 1024)) # 400GB in KB
    
    if [[ $available_space -lt $min_space ]]; then
        error "Available disk space is less than 400GB. You need at least 400GB for Android source."
        exit 1
    fi
    
    success "All prerequisites are met."
}

init_repo() {
    local branch="$1"
    local depth="$2"
    local jobs="$3"
    local no_clone_bundle="$4"
    
    log "Initializing repository for $branch..."
    
    local repo_args="-u https://android.googlesource.com/platform/manifest -b $branch"
    
    if [[ $depth -gt 0 ]]; then
        repo_args="$repo_args --depth=$depth"
    fi
    
    if [[ $no_clone_bundle == true ]]; then
        repo_args="$repo_args --no-clone-bundle"
    fi
    
    repo init $repo_args
    
    success "Repository initialized successfully."
}

sync_repo() {
    local jobs="$1"
    local no_clone_bundle="$2"
    
    log "Syncing repository with $jobs parallel jobs..."
    
    local sync_args="-c -j$jobs --force-sync --no-tags"
    
    if [[ $no_clone_bundle == true ]]; then
        sync_args="$sync_args --no-clone-bundle"
    fi
    
    repo sync $sync_args
    
    success "Repository sync completed."
}

setup_local_manifests() {
    log "Setting up local manifests for Pixel 9 Pro XL..."
    
    local manifest_dir=".repo/local_manifests"
    mkdir -p "$manifest_dir"
    
    # Copy our komodo.xml if it exists
    if [[ -f "local_manifests/komodo.xml" ]]; then
        cp "local_manifests/komodo.xml" "$manifest_dir/"
        success "Local manifest copied successfully."
    else
        warn "No local manifest found. You may need to create one manually."
    fi
}

setup_build_environment() {
    log "Setting up build environment..."
    
    # Install required packages (Ubuntu/Debian)
    if command -v apt-get &> /dev/null; then
        log "Detected Ubuntu/Debian system. Installing required packages..."
        sudo apt-get update
        sudo apt-get install -y \
            bc \
            bison \
            build-essential \
            ccache \
            curl \
            flex \
            g++-multilib \
            gcc-multilib \
            git \
            gnupg \
            gperf \
            imagemagick \
            lib32ncurses5-dev \
            lib32readline-dev \
            lib32z1-dev \
            liblz4-tool \
            libncurses5 \
            libncurses5-dev \
            libsdl1.2-dev \
            libssl-dev \
            libxml2 \
            libxml2-utils \
            lzop \
            pngcrush \
            rsync \
            schedtool \
            squashfs-tools \
            xsltproc \
            zip \
            zlib1g-dev \
            python3 \
            python3-pip
        
        success "Required packages installed."
    fi
    
    # Set up ccache
    log "Setting up ccache..."
    export USE_CCACHE=1
    export CCACHE_DIR="$HOME/.ccache"
    ccache -M 50G
    
    success "ccache configured with 50GB cache."
}

verify_setup() {
    log "Verifying setup..."
    
    # Check if build/envsetup.sh exists
    if [[ ! -f "build/envsetup.sh" ]]; then
        error "build/envsetup.sh not found. Repository sync may have failed."
        exit 1
    fi
    
    # Check if device tree exists (after sync)
    if [[ -d "device/google/$DEVICE" ]]; then
        success "Device tree found for $DEVICE."
    else
        warn "Device tree for $DEVICE not found. You may need to add it manually."
    fi
    
    # Check if kernel source exists
    if [[ -d "kernel/google/gs/caimito" ]]; then
        success "Kernel source found for Tensor G4."
    else
        warn "Kernel source not found. Check your local manifest."
    fi
    
    success "Setup verification completed."
}

create_build_info() {
    log "Creating build information file..."
    
    cat > "build-info-$DEVICE.txt" << EOF
Build Environment Information
=============================
Device: $DEVICE (Pixel 9 Pro XL)
Android Version: $ANDROID_VERSION
Initialized: $(date)
Host: $(hostname)
User: $(whoami)
Repo Version: $(repo version | head -1)
Git Version: $(git --version)

Directory Structure:
- Source: $ANDROID_ROOT
- Device: device/google/$DEVICE
- Vendor: vendor/google/$DEVICE
- Kernel: kernel/google/gs/caimito

Build Scripts:
- scripts/build-rom.sh        # Main build script
- scripts/extract-blobs.sh    # Blob extraction
- config/komodo-build.conf    # Device configuration

Next Steps:
1. Extract proprietary blobs: ./scripts/extract-blobs.sh -a
2. Build ROM: ./scripts/build-rom.sh
3. Flash ROM: Follow generated flash script

For help: ./scripts/build-rom.sh --help
EOF
    
    success "Build information saved to build-info-$DEVICE.txt"
}

main() {
    local branch="$ANDROID_VERSION"
    local depth=1
    local jobs=$(nproc)
    local no_clone_bundle=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -b|--branch)
                branch="$2"
                shift 2
                ;;
            -d|--depth)
                depth="$2"
                shift 2
                ;;
            -j|--jobs)
                jobs="$2"
                shift 2
                ;;
            --no-clone-bundle)
                no_clone_bundle=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    log "Initializing Android build environment for $DEVICE"
    log "Branch: $branch"
    log "Jobs: $jobs"
    
    check_prerequisites
    setup_local_manifests
    init_repo "$branch" "$depth" "$jobs" "$no_clone_bundle"
    setup_build_environment
    sync_repo "$jobs" "$no_clone_bundle"
    verify_setup
    create_build_info
    
    success "Repository initialization completed successfully!"
    success "You can now build your ROM using: ./scripts/build-rom.sh"
}

main "$@"
