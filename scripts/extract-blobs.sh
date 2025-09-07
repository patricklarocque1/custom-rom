#!/bin/bash

# Extraction script for Pixel 9 Pro XL (komodo) proprietary blobs
# This script extracts proprietary files from factory images or OTA files

set -e

DEVICE="komodo"
VENDOR="google"
ANDROID_ROOT="$(pwd)"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

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
    -f, --factory-image PATH    Path to factory image ZIP file
    -o, --ota-package PATH      Path to OTA package ZIP file
    -a, --adb                   Extract from connected device via ADB
    -h, --help                  Show this help message

Examples:
    $0 -f komodo-ap4a.241205.013-factory-*.zip
    $0 -o komodo-ota-ap4a.241205.013-*.zip
    $0 -a

EOF
}

check_dependencies() {
    log "Checking dependencies..."
    
    local deps=("unzip" "7z" "adb")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            error "$dep is not installed. Please install it first."
            exit 1
        fi
    done
    
    success "All dependencies are available."
}

extract_from_factory() {
    local factory_zip="$1"
    
    if [[ ! -f "$factory_zip" ]]; then
        error "Factory image not found: $factory_zip"
        exit 1
    fi
    
    log "Extracting from factory image: $factory_zip"
    
    local temp_dir=$(mktemp -d)
    local extract_dir="$temp_dir/factory"
    
    mkdir -p "$extract_dir"
    unzip -q "$factory_zip" -d "$extract_dir"
    
    # Find the actual factory image directory
    local factory_dir=$(find "$extract_dir" -name "*.zip" -type f | head -1)
    if [[ -n "$factory_dir" ]]; then
        local factory_inner_dir="$temp_dir/inner"
        mkdir -p "$factory_inner_dir"
        unzip -q "$factory_dir" -d "$factory_inner_dir"
        
        # Extract system, vendor, product partitions
        extract_partitions "$factory_inner_dir"
    fi
    
    cleanup_temp "$temp_dir"
}

extract_from_ota() {
    local ota_package="$1"
    
    if [[ ! -f "$ota_package" ]]; then
        error "OTA package not found: $ota_package"
        exit 1
    fi
    
    log "Extracting from OTA package: $ota_package"
    
    local temp_dir=$(mktemp -d)
    local extract_dir="$temp_dir/ota"
    
    mkdir -p "$extract_dir"
    unzip -q "$ota_package" -d "$extract_dir"
    
    extract_partitions "$extract_dir"
    cleanup_temp "$temp_dir"
}

extract_from_device() {
    log "Extracting from connected device via ADB..."
    
    # Check if device is connected
    if ! adb devices | grep -q "device$"; then
        error "No device connected via ADB. Please connect your device and enable USB debugging."
        exit 1
    fi
    
    local temp_dir=$(mktemp -d)
    local device_dir="$temp_dir/device"
    mkdir -p "$device_dir"
    
    log "Pulling system files from device..."
    
    # Create extraction script for device
    cat > "$device_dir/extract.sh" << 'DEVICE_EOF'
#!/system/bin/sh
mkdir -p /tmp/extraction
cp -r /system /tmp/extraction/
cp -r /vendor /tmp/extraction/
cp -r /product /tmp/extraction/
DEVICE_EOF
    
    # Push and execute extraction script
    adb push "$device_dir/extract.sh" /tmp/
    adb shell "chmod +x /tmp/extract.sh && /tmp/extract.sh"
    
    # Pull extracted files
    adb pull /tmp/extraction "$device_dir/"
    
    extract_partitions "$device_dir/extraction"
    cleanup_temp "$temp_dir"
}

extract_partitions() {
    local source_dir="$1"
    
    log "Processing partition images..."
    
    local vendor_dir="$ANDROID_ROOT/vendor/$VENDOR"
    local device_vendor_dir="$vendor_dir/$DEVICE"
    
    mkdir -p "$device_vendor_dir"
    
    # Extract vendor blobs using device-specific extraction list
    if [[ -f "$ANDROID_ROOT/device/$VENDOR/$DEVICE/proprietary-files.txt" ]]; then
        log "Using device-specific proprietary files list..."
        python3 "$ANDROID_ROOT/device/$VENDOR/$DEVICE/extract-files.py" "$source_dir"
    else
        warn "No proprietary files list found. Creating generic extraction..."
        create_generic_extraction "$source_dir"
    fi
}

create_generic_extraction() {
    local source_dir="$1"
    
    log "Creating generic blob extraction..."
    
    local vendor_dir="$ANDROID_ROOT/vendor/$VENDOR/$DEVICE/proprietary"
    mkdir -p "$vendor_dir"
    
    # Common proprietary file patterns for Pixel devices
    local patterns=(
        "*/lib*/lib*gril*"
        "*/lib*/lib*ril*"
        "*/lib*/vendor.qti*"
        "*/lib*/lib*qmi*"
        "*/bin/*radio*"
        "*/bin/*thermal*"
        "*/etc/permissions/*"
        "*/framework/*.jar"
    )
    
    for pattern in "${patterns[@]}"; do
        find "$source_dir" -path "$pattern" -type f 2>/dev/null | while read -r file; do
            local rel_path=${file#$source_dir/}
            local dest_dir="$vendor_dir/$(dirname "$rel_path")"
            mkdir -p "$dest_dir"
            cp "$file" "$dest_dir/"
            log "Extracted: $rel_path"
        done
    done
}

cleanup_temp() {
    local temp_dir="$1"
    if [[ -n "$temp_dir" && -d "$temp_dir" ]]; then
        rm -rf "$temp_dir"
        log "Cleaned up temporary directory: $temp_dir"
    fi
}

generate_makefiles() {
    log "Generating vendor makefiles..."
    
    local vendor_dir="$ANDROID_ROOT/vendor/$VENDOR/$DEVICE"
    
    # Generate Android.mk
    cat > "$vendor_dir/Android.mk" << EOF
# Automatically generated file. DO NOT MODIFY
LOCAL_PATH := \$(call my-dir)

ifeq (\$(TARGET_DEVICE),$DEVICE)
\$(call inherit-product, vendor/$VENDOR/$DEVICE/$DEVICE-vendor.mk)
endif
EOF

    # Generate device-vendor.mk
    cat > "$vendor_dir/$DEVICE-vendor.mk" << EOF
# Automatically generated file. DO NOT MODIFY

PRODUCT_COPY_FILES += \\
EOF

    # Add proprietary files to makefile
    if [[ -d "$vendor_dir/proprietary" ]]; then
        find "$vendor_dir/proprietary" -type f | while read -r file; do
            local rel_path=${file#$vendor_dir/proprietary/}
            echo "    vendor/$VENDOR/$DEVICE/proprietary/$rel_path:\$(TARGET_COPY_OUT_VENDOR)/$rel_path \\" >> "$vendor_dir/$DEVICE-vendor.mk"
        done
    fi
    
    success "Vendor makefiles generated successfully!"
}

main() {
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi
    
    check_dependencies
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--factory-image)
                extract_from_factory "$2"
                shift 2
                ;;
            -o|--ota-package)
                extract_from_ota "$2"
                shift 2
                ;;
            -a|--adb)
                extract_from_device
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
    
    generate_makefiles
    success "Blob extraction completed successfully!"
    log "You can now run 'repo sync' to ensure all repositories are up to date."
}

main "$@"
