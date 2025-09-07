#!/bin/bash

# Automated build script for Pixel 9 Pro XL (komodo) custom ROM
# Supports AOSP, LineageOS, and other ROM variants

set -e

DEVICE="komodo"
ANDROID_ROOT="$(pwd)"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Default configuration
ROM_TYPE="aosp"
BUILD_TYPE="userdebug"
CLEAN_BUILD=false
SYNC_REPO=true
CCACHE_ENABLED=true
JOBS=$(nproc)

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    -r, --rom-type TYPE         ROM type (aosp, lineage, pixel) [default: aosp]
    -t, --build-type TYPE       Build type (user, userdebug, eng) [default: userdebug]
    -c, --clean                 Perform clean build
    -s, --skip-sync             Skip repo sync
    -j, --jobs NUM              Number of parallel jobs [default: $(nproc)]
    --no-ccache                 Disable ccache
    -h, --help                  Show this help message

Examples:
    $0                          # Build AOSP userdebug
    $0 -r lineage -t user       # Build LineageOS user
    $0 -c -j 8                  # Clean build with 8 jobs
    $0 --skip-sync              # Build without syncing

EOF
}

check_environment() {
    log "Checking build environment..."
    
    # Check if we're in the Android root directory
    if [[ ! -f "build/envsetup.sh" ]]; then
        error "Not in Android root directory. Please run this script from the root of your Android source tree."
        exit 1
    fi
    
    # Check available disk space (minimum 200GB)
    local available_space=$(df . | awk 'NR==2 {print $4}')
    local min_space=$((200 * 1024 * 1024)) # 200GB in KB
    
    if [[ $available_space -lt $min_space ]]; then
        warn "Available disk space is less than 200GB. Build may fail due to insufficient space."
    fi
    
    # Check RAM (minimum 16GB recommended)
    local total_ram=$(free -g | awk 'NR==2{printf "%.0f", $2}')
    if [[ $total_ram -lt 16 ]]; then
        warn "System has less than 16GB RAM. Consider reducing parallel jobs."
        JOBS=$((JOBS / 2))
        if [[ $JOBS -lt 1 ]]; then
            JOBS=1
        fi
    fi
    
    success "Environment check completed."
}

setup_ccache() {
    if [[ $CCACHE_ENABLED == true ]]; then
        log "Setting up ccache..."
        
        export USE_CCACHE=1
        export CCACHE_EXEC=/usr/bin/ccache
        export CCACHE_DIR=$HOME/.ccache
        
        # Set ccache size to 50GB
        ccache -M 50G
        
        success "ccache configured with 50GB cache size."
    else
        log "ccache disabled."
    fi
}

sync_repositories() {
    if [[ $SYNC_REPO == true ]]; then
        log "Syncing repositories..."
        
        repo sync -c -j$JOBS --force-sync --no-clone-bundle --no-tags
        
        success "Repository sync completed."
    else
        log "Skipping repository sync."
    fi
}

setup_build_environment() {
    log "Setting up build environment..."
    
    source build/envsetup.sh
    
    # Set build target based on ROM type
    case $ROM_TYPE in
        "aosp")
            lunch "aosp_${DEVICE}-${BUILD_TYPE}"
            ;;
        "lineage")
            lunch "lineage_${DEVICE}-${BUILD_TYPE}"
            ;;
        "pixel")
            lunch "aosp_${DEVICE}-${BUILD_TYPE}"
            ;;
        *)
            error "Unknown ROM type: $ROM_TYPE"
            exit 1
            ;;
    esac
    
    success "Build environment configured for ${ROM_TYPE}_${DEVICE}-${BUILD_TYPE}"
}

perform_clean_build() {
    if [[ $CLEAN_BUILD == true ]]; then
        log "Performing clean build..."
        
        make clobber
        
        success "Clean build preparation completed."
    fi
}

build_kernel() {
    log "Building kernel for Tensor G4 (Caimito)..."
    
    # Build kernel separately for better control
    if [[ -d "kernel/google/gs/caimito" ]]; then
        cd kernel/google/gs/caimito
        
        # Set up kernel build environment
        export ARCH=arm64
        export CROSS_COMPILE=aarch64-linux-android-
        export CROSS_COMPILE_ARM32=arm-linux-androideabi-
        
        # Build kernel
        make O=out caimito_gki_defconfig
        make O=out -j$JOBS
        
        cd "$ANDROID_ROOT"
        success "Kernel build completed."
    else
        warn "Kernel source not found. Kernel will be built as part of ROM build."
    fi
}

build_rom() {
    local start_time=$(date +%s)
    
    log "Starting ROM build..."
    log "ROM Type: $ROM_TYPE"
    log "Device: $DEVICE"
    log "Build Type: $BUILD_TYPE"
    log "Jobs: $JOBS"
    
    # Build the ROM
    case $ROM_TYPE in
        "aosp")
            make -j$JOBS dist
            ;;
        "lineage")
            brunch $DEVICE
            ;;
        "pixel")
            make -j$JOBS dist
            ;;
        *)
            error "Unknown ROM type for build: $ROM_TYPE"
            exit 1
            ;;
    esac
    
    local end_time=$(date +%s)
    local build_time=$((end_time - start_time))
    local hours=$((build_time / 3600))
    local minutes=$(((build_time % 3600) / 60))
    local seconds=$((build_time % 60))
    
    success "ROM build completed successfully!"
    log "Build time: ${hours}h ${minutes}m ${seconds}s"
}

package_build() {
    log "Packaging build artifacts..."
    
    local out_dir="out/target/product/$DEVICE"
    local dist_dir="out/dist"
    local package_dir="$HOME/android-builds/$(date +%Y%m%d_%H%M%S)_${ROM_TYPE}_${DEVICE}_${BUILD_TYPE}"
    
    mkdir -p "$package_dir"
    
    # Copy main build artifacts
    if [[ -f "$out_dir/boot.img" ]]; then
        cp "$out_dir/boot.img" "$package_dir/"
    fi
    
    if [[ -f "$out_dir/recovery.img" ]]; then
        cp "$out_dir/recovery.img" "$package_dir/"
    fi
    
    # Copy ROM zip if it exists
    local rom_zip=$(find "$out_dir" -name "*${DEVICE}*.zip" -type f | head -1)
    if [[ -n "$rom_zip" ]]; then
        cp "$rom_zip" "$package_dir/"
    fi
    
    # Copy factory images if they exist
    if [[ -d "$dist_dir" ]]; then
        find "$dist_dir" -name "*${DEVICE}*" -type f | while read -r file; do
            cp "$file" "$package_dir/"
        done
    fi
    
    # Create build info
    cat > "$package_dir/build-info.txt" << EOF
Build Information
=================
ROM Type: $ROM_TYPE
Device: $DEVICE (Pixel 9 Pro XL)
Build Type: $BUILD_TYPE
Build Date: $(date)
Build Host: $(hostname)
Git Revision: $(git rev-parse HEAD 2>/dev/null || echo "Unknown")
Jobs Used: $JOBS
ccache: $(if [[ $CCACHE_ENABLED == true ]]; then echo "Enabled"; else echo "Disabled"; fi)
EOF
    
    success "Build artifacts packaged in: $package_dir"
}

generate_flash_script() {
    local package_dir="$1"
    
    log "Generating flash script..."
    
    cat > "$package_dir/flash-${DEVICE}.sh" << 'EOF'
#!/bin/bash

# Flash script for Pixel 9 Pro XL (komodo)
# WARNING: This will wipe your device!

set -e

DEVICE="komodo"

error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

log() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

# Check if fastboot is available
if ! command -v fastboot &> /dev/null; then
    error "fastboot is not installed. Please install Android SDK platform-tools."
    exit 1
fi

# Check if device is in fastboot mode
if ! fastboot devices | grep -q "$DEVICE\|fastboot"; then
    error "Device not detected in fastboot mode."
    error "Please boot your device into fastboot mode and try again."
    exit 1
fi

log "Flashing Pixel 9 Pro XL (komodo)..."

# Unlock bootloader if needed
log "Checking bootloader status..."
if fastboot getvar unlocked 2>&1 | grep -q "no"; then
    error "Bootloader is locked. Please unlock it first:"
    error "fastboot flashing unlock"
    exit 1
fi

# Flash images
if [[ -f "boot.img" ]]; then
    log "Flashing boot image..."
    fastboot flash boot boot.img
fi

if [[ -f "recovery.img" ]]; then
    log "Flashing recovery image..."
    fastboot flash recovery recovery.img
fi

# Flash factory image if available
ROM_ZIP=$(find . -name "*${DEVICE}*.zip" -type f | head -1)
if [[ -n "$ROM_ZIP" ]]; then
    log "Flashing ROM: $ROM_ZIP"
    fastboot -w update "$ROM_ZIP"
else
    log "No ROM zip found. Flashing individual images only."
fi

# Reboot
log "Rebooting device..."
fastboot reboot

success "Flashing completed successfully!"
success "Your device should now boot with the new ROM."
EOF
    
    chmod +x "$package_dir/flash-${DEVICE}.sh"
    success "Flash script created: $package_dir/flash-${DEVICE}.sh"
}

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--rom-type)
                ROM_TYPE="$2"
                shift 2
                ;;
            -t|--build-type)
                BUILD_TYPE="$2"
                shift 2
                ;;
            -c|--clean)
                CLEAN_BUILD=true
                shift
                ;;
            -s|--skip-sync)
                SYNC_REPO=false
                shift
                ;;
            -j|--jobs)
                JOBS="$2"
                shift 2
                ;;
            --no-ccache)
                CCACHE_ENABLED=false
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
    
    log "Starting build process for Pixel 9 Pro XL (komodo)"
    log "Configuration: ${ROM_TYPE}_${DEVICE}-${BUILD_TYPE}"
    
    check_environment
    setup_ccache
    sync_repositories
    setup_build_environment
    perform_clean_build
    build_kernel
    build_rom
    
    local package_dir
    package_dir=$(package_build | grep "Build artifacts packaged in:" | awk '{print $5}')
    
    if [[ -n "$package_dir" ]]; then
        generate_flash_script "$package_dir"
    fi
    
    success "Build process completed successfully!"
    log "Your ROM is ready for flashing."
}

# Run main function with all arguments
main "$@"
