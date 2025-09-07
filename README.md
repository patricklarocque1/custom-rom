# Pixel 9 Pro XL (komodo) Custom ROM Development

Complete development environment for building custom ROMs for the **Google Pixel 9 Pro XL** (codename: `komodo`) with **Android 16** and **Tensor G4** support.

## 🔧 Quick Start

### Prerequisites

- **OS**: Ubuntu 18.04+ / Debian 9+ (recommended)
- **Storage**: Minimum 400GB free space
- **RAM**: 16GB+ recommended (8GB minimum)
- **CPU**: Multi-core processor (higher core count = faster builds)

### 1. Initialize Environment

```bash
# Clone this repository
git clone <your-repo-url> custom-rom
cd custom-rom

# Make scripts executable
chmod +x scripts/*.sh config/*.sh

# Initialize Android source tree
./config/repo-init.sh
```

### 2. Extract Proprietary Blobs

Choose one method:

```bash
# From factory image
./scripts/extract-blobs.sh -f komodo-ap4a.241205.013-factory-*.zip

# From OTA package
./scripts/extract-blobs.sh -o komodo-ota-ap4a.241205.013-*.zip

# From connected device (requires ADB)
./scripts/extract-blobs.sh -a
```

### 3. Build ROM

```bash
# Build AOSP (default)
./scripts/build-rom.sh

# Build LineageOS
./scripts/build-rom.sh -r lineage

# Clean build with 8 jobs
./scripts/build-rom.sh -c -j 8
```

## 📱 Device Information

| Specification | Details |
|---------------|---------|
| **Device** | Google Pixel 9 Pro XL |
| **Codename** | `komodo` |
| **SoC** | Google Tensor G4 |
| **Architecture** | ARM64 |
| **Android Version** | 16 (API 35) |
| **Kernel** | Linux 6.1 (GKI) |
| **Display** | 6.8" LTPO OLED, 2992x1344 |

## 🗂️ Project Structure

```
custom-rom/
├── local_manifests/           # Repository manifests
│   └── komodo.xml            # Device-specific repositories
├── scripts/                   # Build automation
│   ├── build-rom.sh          # Main ROM build script
│   ├── extract-blobs.sh      # Proprietary blob extraction
│   └── build-kernel.sh       # Kernel build script
├── config/                    # Configuration files
│   ├── komodo-build.conf     # Device-specific build config
│   └── repo-init.sh          # Repository initialization
└── README.md                 # This file
```

## 🔨 Build Scripts

### Main Build Script (`build-rom.sh`)

Automated ROM building with support for multiple ROM types:

```bash
./scripts/build-rom.sh [OPTIONS]

Options:
  -r, --rom-type TYPE         ROM type (aosp, lineage, pixel) [default: aosp]
  -t, --build-type TYPE       Build type (user, userdebug, eng) [default: userdebug]
  -c, --clean                 Perform clean build
  -s, --skip-sync             Skip repo sync
  -j, --jobs NUM              Number of parallel jobs [default: CPU cores]
  --no-ccache                 Disable ccache

Examples:
  ./scripts/build-rom.sh                    # AOSP userdebug build
  ./scripts/build-rom.sh -r lineage -t user # LineageOS user build
  ./scripts/build-rom.sh -c -j 8            # Clean build with 8 jobs
```

### Blob Extraction (`extract-blobs.sh`)

Extract proprietary blobs from various sources:

```bash
./scripts/extract-blobs.sh [OPTIONS]

Options:
  -f, --factory-image PATH    Path to factory image ZIP
  -o, --ota-package PATH      Path to OTA package ZIP
  -a, --adb                   Extract from connected device

Examples:
  ./scripts/extract-blobs.sh -f komodo-factory-*.zip
  ./scripts/extract-blobs.sh -a
```

### Kernel Build (`build-kernel.sh`)

Build kernel separately for development/testing:

```bash
./scripts/build-kernel.sh [OPTIONS]

Options:
  -c, --config CONFIG         Kernel config [default: caimito_gki_defconfig]
  --clean                     Clean build
  -j, --jobs JOBS             Parallel jobs
  --modules-only              Build modules only
  --config-only               Generate config only

Examples:
  ./scripts/build-kernel.sh                 # Standard kernel build
  ./scripts/build-kernel.sh --clean -j 8    # Clean build with 8 jobs
```

## 🏗️ Supported ROM Types

### AOSP (Android Open Source Project)
- Pure Google Android experience
- Latest Android 16 features
- Minimal bloat

### LineageOS
- Privacy-focused custom ROM
- Extended customization options
- Regular security updates

### Pixel Experience
- Stock Pixel ROM experience
- Google apps included
- Pixel-specific features

## ⚙️ Configuration

### Device Configuration (`config/komodo-build.conf`)

Device-specific build settings including:
- Partition sizes and layout
- Hardware-specific flags
- Display and audio configuration
- Security and bootloader settings

### Repository Manifests (`local_manifests/komodo.xml`)

Defines additional repositories for:
- Device tree (`device/google/komodo`)
- Vendor blobs (`vendor/google`)
- Kernel source (`kernel/google/gs/caimito`)
- Hardware abstraction layers

## 🚀 Advanced Usage

### Custom Kernel Development

```bash
# Build kernel with custom config
./scripts/build-kernel.sh -c my_custom_defconfig

# Build modules only (for testing)
./scripts/build-kernel.sh --modules-only

# Generate config and edit manually
./scripts/build-kernel.sh --config-only
# Edit: kernel/google/gs/caimito/out/.config
./scripts/build-kernel.sh
```

### Multi-Target Building

```bash
# Build multiple variants
./scripts/build-rom.sh -r aosp -t userdebug
./scripts/build-rom.sh -r lineage -t user
```

### Development Workflow

1. **Initial Setup**:
   ```bash
   ./config/repo-init.sh
   ./scripts/extract-blobs.sh -a
   ```

2. **Development Cycle**:
   ```bash
   # Make changes to source
   ./scripts/build-rom.sh -s        # Skip sync for faster builds
   ```

3. **Testing**:
   ```bash
   ./scripts/build-kernel.sh --clean # Test kernel changes
   ./scripts/build-rom.sh -c        # Full clean build
   ```

## 📦 Build Outputs

### ROM Build Outputs
- **Location**: `~/android-builds/YYYYMMDD_HHMMSS_<rom>_<device>_<type>/`
- **Contents**:
  - `boot.img` - Boot image
  - `recovery.img` - Recovery image  
  - `*komodo*.zip` - Flashable ROM package
  - `build-info.txt` - Build metadata
  - `flash-komodo.sh` - Automated flash script

### Kernel Build Outputs
- **Location**: `~/kernel-builds/YYYYMMDD_HHMMSS_komodo_kernel/`
- **Contents**:
  - `Image` / `Image.gz` - Kernel images
  - `dts/` - Device tree blobs
  - `modules_staging/` - Kernel modules
  - `flash-kernel.sh` - Kernel flash script

## 🔧 Troubleshooting

### Common Issues

**Build Fails with "No space left on device"**
```bash
# Check disk space
df -h .
# Clean previous builds
make clean
ccache -C
```

**Missing proprietary blobs**
```bash
# Re-extract blobs
./scripts/extract-blobs.sh -a
# Or download factory image and extract
./scripts/extract-blobs.sh -f komodo-factory-*.zip
```

**Kernel build fails**
```bash
# Clean kernel build
./scripts/build-kernel.sh --clean
# Check toolchain
source build/envsetup.sh
```

**Repo sync issues**
```bash
# Force sync
repo sync --force-sync --no-clone-bundle
# Or re-initialize
rm -rf .repo
./config/repo-init.sh
```

### Performance Optimization

**Faster Builds**
- Enable ccache (default)
- Use more parallel jobs: `-j $(nproc)`
- Use SSD for source directory
- Increase RAM if possible

**ccache Configuration**
```bash
# Check ccache stats
ccache -s
# Increase cache size
ccache -M 100G
# Clear cache if needed
ccache -C
```

## 📚 Resources

### Official Documentation
- [Android Source](https://source.android.com/)
- [Pixel Factory Images](https://developers.google.com/android/images)
- [LineageOS Wiki](https://wiki.lineageos.org/)

### Hardware References
- [Tensor G4 Documentation](https://developers.google.com/android/soc/tensor)
- [Pixel 9 Pro XL Specs](https://store.google.com/product/pixel_9_pro)

### Community
- [XDA Developers](https://forum.xda-developers.com/pixel-9-pro-xl)
- [r/GooglePixel](https://reddit.com/r/GooglePixel)

## ⚠️ Disclaimer

- Building and flashing custom ROMs will **void your warranty**
- Requires **unlocked bootloader** (will wipe data)
- **Backup your device** before proceeding
- This is for **development purposes** - daily driver use at your own risk

## 📄 License

This project is provided under the Apache 2.0 License. Individual components may have their own licenses.

---

**Happy building!** 🚀

For issues or questions, please create an issue in this repository.