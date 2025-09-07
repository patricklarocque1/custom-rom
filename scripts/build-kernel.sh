#!/bin/bash

# Kernel build script for Pixel 9 Pro XL (komodo) - Tensor G4 (Caimito)
# Builds the kernel separately from the main ROM build

set -e

DEVICE="komodo"
KERNEL_FAMILY="caimito"
KERNEL_ARCH="arm64"
ANDROID_ROOT="$(pwd)"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Default configuration
BUILD_CONFIG="caimito_gki_defconfig"
BUILD_CLEAN=false
BUILD_JOBS=$(nproc)
OUTPUT_DIR="out"
KERNEL_SOURCE="kernel/google/gs/caimito"

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
    -c, --config CONFIG         Kernel config [default: caimito_gki_defconfig]
    --clean                     Clean build (remove output directory)
    -j, --jobs JOBS             Number of parallel jobs [default: $(nproc)]
    -o, --output DIR            Output directory [default: out]
    -s, --source DIR            Kernel source directory [default: kernel/google/gs/caimito]
    --modules-only              Build modules only
    --config-only               Generate config only
    -h, --help                  Show this help message

Configurations:
    caimito_gki_defconfig       # Standard GKI configuration
    caimito_defconfig           # Full device configuration
    
Examples:
    $0                          # Build with defaults
    $0 --clean -j 8             # Clean build with 8 jobs
    $0 --config-only            # Generate config only
    $0 --modules-only           # Build kernel modules only

EOF
}

check_environment() {
    log "Checking kernel build environment..."
    
    # Check if we're in the Android root
    if [[ ! -f "build/envsetup.sh" ]]; then
        error "Not in Android root directory. Please run from the root of your Android source tree."
        exit 1
    fi
    
    # Check if kernel source exists
    if [[ ! -d "$KERNEL_SOURCE" ]]; then
        error "Kernel source not found at: $KERNEL_SOURCE"
        error "Please ensure you have synced the kernel source."
        exit 1
    fi
    
    # Check for required tools
    local tools=("make" "gcc" "aarch64-linux-android-gcc" "arm-linux-androideabi-gcc")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            warn "$tool not found in PATH. Setting up Android toolchain..."
            setup_toolchain
            break
        fi
    done
    
    success "Environment check completed."
}

setup_toolchain() {
    log "Setting up Android toolchain..."
    
    # Source Android environment
    if [[ -f "build/envsetup.sh" ]]; then
        source build/envsetup.sh &>/dev/null
    fi
    
    # Set up cross compilation toolchain
    export ARCH="$KERNEL_ARCH"
    export SUBARCH="$KERNEL_ARCH"
    export CROSS_COMPILE="aarch64-linux-android-"
    export CROSS_COMPILE_ARM32="arm-linux-androideabi-"
    export CROSS_COMPILE_COMPAT="arm-linux-androideabi-"
    
    # Android specific
    export ANDROID_MAJOR_VERSION=u
    export PLATFORM_VERSION=16
    export ANDROID_VERSION=16
    
    # Clang setup
    if [[ -d "prebuilts/clang/host/linux-x86" ]]; then
        local clang_version=$(find prebuilts/clang/host/linux-x86 -maxdepth 1 -name "clang-r*" | sort -V | tail -1)
        if [[ -n "$clang_version" ]]; then
            export PATH="$clang_version/bin:$PATH"
            export CC=clang
            export CXX=clang++
            log "Using Clang from: $clang_version"
        fi
    fi
    
    # GCC Toolchain paths
    if [[ -d "prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9" ]]; then
        export PATH="prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin:$PATH"
    fi
    
    if [[ -d "prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9" ]]; then
        export PATH="prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/bin:$PATH"
    fi
    
    success "Toolchain configured."
}

clean_build() {
    if [[ $BUILD_CLEAN == true ]]; then
        log "Cleaning previous build..."
        
        cd "$KERNEL_SOURCE"
        
        if [[ -d "$OUTPUT_DIR" ]]; then
            rm -rf "$OUTPUT_DIR"
            log "Removed output directory: $OUTPUT_DIR"
        fi
        
        make mrproper
        
        cd "$ANDROID_ROOT"
        success "Clean completed."
    fi
}

generate_config() {
    log "Generating kernel configuration: $BUILD_CONFIG"
    
    cd "$KERNEL_SOURCE"
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Generate configuration
    make O="$OUTPUT_DIR" ARCH="$KERNEL_ARCH" "$BUILD_CONFIG"
    
    # Apply any device-specific configuration fragments
    local config_fragments=(
        "android-base.config"
        "android-recommended.config"
        "caimito-gki.config"
    )
    
    for fragment in "${config_fragments[@]}"; do
        if [[ -f "arch/$KERNEL_ARCH/configs/$fragment" ]]; then
            log "Applying config fragment: $fragment"
            scripts/kconfig/merge_config.sh -O "$OUTPUT_DIR" "$OUTPUT_DIR/.config" "arch/$KERNEL_ARCH/configs/$fragment"
        fi
    done
    
    # Final configuration update
    make O="$OUTPUT_DIR" ARCH="$KERNEL_ARCH" olddefconfig
    
    cd "$ANDROID_ROOT"
    success "Configuration generated successfully."
}

build_kernel() {
    local start_time=$(date +%s)
    
    log "Building kernel for Pixel 9 Pro XL (Tensor G4)..."
    log "Configuration: $BUILD_CONFIG"
    log "Jobs: $BUILD_JOBS"
    log "Architecture: $KERNEL_ARCH"
    
    cd "$KERNEL_SOURCE"
    
    # Build the kernel
    make O="$OUTPUT_DIR" \
         ARCH="$KERNEL_ARCH" \
         -j"$BUILD_JOBS" \
         all
    
    local end_time=$(date +%s)
    local build_time=$((end_time - start_time))
    local minutes=$((build_time / 60))
    local seconds=$((build_time % 60))
    
    cd "$ANDROID_ROOT"
    success "Kernel build completed in ${minutes}m ${seconds}s"
}

build_modules() {
    log "Building kernel modules..."
    
    cd "$KERNEL_SOURCE"
    
    # Build modules
    make O="$OUTPUT_DIR" \
         ARCH="$KERNEL_ARCH" \
         -j"$BUILD_JOBS" \
         modules
    
    # Install modules to staging directory
    local modules_dir="$OUTPUT_DIR/modules_staging"
    make O="$OUTPUT_DIR" \
         ARCH="$KERNEL_ARCH" \
         INSTALL_MOD_PATH="$modules_dir" \
         modules_install
    
    cd "$ANDROID_ROOT"
    success "Kernel modules built and staged."
}

package_kernel() {
    log "Packaging kernel artifacts..."
    
    local kernel_out="$KERNEL_SOURCE/$OUTPUT_DIR"
    local package_dir="$HOME/kernel-builds/$(date +%Y%m%d_%H%M%S)_${DEVICE}_kernel"
    
    mkdir -p "$package_dir"
    
    # Copy kernel image
    if [[ -f "$kernel_out/arch/$KERNEL_ARCH/boot/Image" ]]; then
        cp "$kernel_out/arch/$KERNEL_ARCH/boot/Image" "$package_dir/"
        success "Kernel Image packaged"
    fi
    
    # Copy compressed kernel image
    if [[ -f "$kernel_out/arch/$KERNEL_ARCH/boot/Image.gz" ]]; then
        cp "$kernel_out/arch/$KERNEL_ARCH/boot/Image.gz" "$package_dir/"
        success "Compressed kernel Image.gz packaged"
    fi
    
    # Copy device tree blobs
    if [[ -d "$kernel_out/arch/$KERNEL_ARCH/boot/dts" ]]; then
        cp -r "$kernel_out/arch/$KERNEL_ARCH/boot/dts" "$package_dir/"
        success "Device tree blobs packaged"
    fi
    
    # Copy kernel configuration
    if [[ -f "$kernel_out/.config" ]]; then
        cp "$kernel_out/.config" "$package_dir/kernel-config"
        success "Kernel configuration packaged"
    fi
    
    # Copy modules if they exist
    if [[ -d "$kernel_out/modules_staging" ]]; then
        cp -r "$kernel_out/modules_staging" "$package_dir/"
        success "Kernel modules packaged"
    fi
    
    # Create build info
    cat > "$package_dir/build-info.txt" << EOF
Kernel Build Information
========================
Device: $DEVICE (Pixel 9 Pro XL)
Kernel Family: $KERNEL_FAMILY (Tensor G4)
Architecture: $KERNEL_ARCH
Configuration: $BUILD_CONFIG
Build Date: $(date)
Build Host: $(hostname)
Source: $KERNEL_SOURCE
Git Revision: $(cd "$KERNEL_SOURCE" && git rev-parse HEAD 2>/dev/null || echo "Unknown")
Compiler: $(${CROSS_COMPILE}gcc --version | head -1 2>/dev/null || echo "Unknown")
Jobs Used: $BUILD_JOBS

Artifacts:
- Image: Uncompressed kernel image
- Image.gz: Compressed kernel image
- dts/: Device tree blobs
- kernel-config: Kernel configuration
- modules_staging/: Loadable kernel modules (if built)
EOF
    
    success "Kernel artifacts packaged in: $package_dir"
}

create_flash_script() {
    local package_dir="$1"
    
    log "Creating kernel flash script..."
    
    cat > "$package_dir/flash-kernel.sh" << 'KERNEL_EOF'
#!/bin/bash

# Flash kernel for Pixel 9 Pro XL (komodo)
# WARNING: This requires unlocked bootloader!

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

# Check fastboot
if ! command -v fastboot &> /dev/null; then
    error "fastboot not found. Please install Android SDK platform-tools."
    exit 1
fi

# Check device
if ! fastboot devices | grep -q "$DEVICE\|fastboot"; then
    error "Device not in fastboot mode. Please boot into fastboot mode."
    exit 1
fi

log "Flashing kernel to Pixel 9 Pro XL..."

# Flash kernel
if [[ -f "Image.gz" ]]; then
    log "Flashing compressed kernel..."
    fastboot flash boot_a Image.gz
    fastboot flash boot_b Image.gz
elif [[ -f "Image" ]]; then
    log "Flashing uncompressed kernel..."
    fastboot flash boot_a Image
    fastboot flash boot_b Image
else
    error "No kernel image found!"
    exit 1
fi

# Flash DTB if available
if [[ -d "dts" ]]; then
    local dtb_file=$(find dts -name "*$DEVICE*.dtb" | head -1)
    if [[ -n "$dtb_file" ]]; then
        log "Flashing device tree: $dtb_file"
        fastboot flash dtbo "$dtb_file"
    fi
fi

log "Rebooting..."
fastboot reboot

success "Kernel flash completed!"
KERNEL_EOF
    
    chmod +x "$package_dir/flash-kernel.sh"
    success "Flash script created: $package_dir/flash-kernel.sh"
}

main() {
    local config_only=false
    local modules_only=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                BUILD_CONFIG="$2"
                shift 2
                ;;
            --clean)
                BUILD_CLEAN=true
                shift
                ;;
            -j|--jobs)
                BUILD_JOBS="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -s|--source)
                KERNEL_SOURCE="$2"
                shift 2
                ;;
            --config-only)
                config_only=true
                shift
                ;;
            --modules-only)
                modules_only=true
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
    
    log "Starting kernel build for $DEVICE (Tensor G4)"
    log "Configuration: $BUILD_CONFIG"
    
    check_environment
    setup_toolchain
    clean_build
    generate_config
    
    if [[ $config_only == true ]]; then
        success "Configuration generated. Run without --config-only to build kernel."
        exit 0
    fi
    
    if [[ $modules_only == true ]]; then
        build_modules
    else
        build_kernel
        build_modules
    fi
    
    local package_dir
    package_dir=$(package_kernel | grep "packaged in:" | awk '{print $5}')
    
    if [[ -n "$package_dir" ]]; then
        create_flash_script "$package_dir"
    fi
    
    success "Kernel build process completed!"
}

main "$@"
