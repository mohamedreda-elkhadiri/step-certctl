#!/bin/bash
set -euo pipefail

PACKAGE_NAME="step-certctl"
VERSION="0.1.0"
ARCH="all"
BUILD_DIR="pkg"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "${SCRIPT_DIR}"

usage() {
    cat <<EOF
Build script for ${PACKAGE_NAME}

Usage: $0 [command]

Commands:
    build       Build the .deb package (default)
    install     Build and install the package
    clean       Remove build artifacts
    help        Show this help message

Examples:
    $0              # Build the package
    $0 build        # Build the package
    $0 install      # Build and install
    $0 clean        # Clean build directory
EOF
}

clean() {
    echo "Cleaning build directory..."
    rm -rf "${BUILD_DIR}"
    rm -f "${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
    echo "Clean complete"
}

build() {
    echo "Building ${PACKAGE_NAME} version ${VERSION}..."

    # Clean previous build
    rm -rf "${BUILD_DIR}"

    # Create package directory structure
    echo "Creating directory structure..."
    mkdir -p "${BUILD_DIR}/DEBIAN"
    mkdir -p "${BUILD_DIR}/usr/bin"
    mkdir -p "${BUILD_DIR}/usr/lib/step-certctl"
    mkdir -p "${BUILD_DIR}/etc/systemd/system"
    mkdir -p "${BUILD_DIR}/usr/share/doc/step-certctl/examples"
    mkdir -p "${BUILD_DIR}/etc/step-certctl"

    # Copy main script
    echo "Copying main script..."
    cp bin/step-certctl "${BUILD_DIR}/usr/bin/"
    chmod 755 "${BUILD_DIR}/usr/bin/step-certctl"

    # Copy library functions
    echo "Copying library functions..."
    cp lib/step-certctl-functions.sh "${BUILD_DIR}/usr/lib/step-certctl/"
    chmod 644 "${BUILD_DIR}/usr/lib/step-certctl/step-certctl-functions.sh"

    # Copy systemd units
    echo "Copying systemd units..."
    cp systemd/step-certctl@.service "${BUILD_DIR}/etc/systemd/system/"
    cp systemd/step-certctl@.timer "${BUILD_DIR}/etc/systemd/system/"
    chmod 644 "${BUILD_DIR}/etc/systemd/system/step-certctl@.service"
    chmod 644 "${BUILD_DIR}/etc/systemd/system/step-certctl@.timer"

    # Copy example configs
    echo "Copying example configs..."
    cp examples/*.conf "${BUILD_DIR}/usr/share/doc/step-certctl/examples/"
    chmod 644 "${BUILD_DIR}/usr/share/doc/step-certctl/examples/"*.conf

    # Copy README
    echo "Copying documentation..."
    cp README.md "${BUILD_DIR}/usr/share/doc/step-certctl/"
    chmod 644 "${BUILD_DIR}/usr/share/doc/step-certctl/README.md"

    # Copy Debian package control files
    echo "Copying package control files..."
    cp debian/control "${BUILD_DIR}/DEBIAN/"
    cp debian/postinst "${BUILD_DIR}/DEBIAN/"
    cp debian/prerm "${BUILD_DIR}/DEBIAN/"
    chmod 755 "${BUILD_DIR}/DEBIAN/postinst"
    chmod 755 "${BUILD_DIR}/DEBIAN/prerm"
    chmod 644 "${BUILD_DIR}/DEBIAN/control"

    # Calculate installed size
    echo "Calculating package size..."
    INSTALLED_SIZE=$(du -sk "${BUILD_DIR}" | cut -f1)
    echo "Installed-Size: ${INSTALLED_SIZE}" >> "${BUILD_DIR}/DEBIAN/control"

    # Build the package
    echo "Building .deb package..."
    dpkg-deb --build "${BUILD_DIR}" "${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"

    echo ""
    echo "Build complete!"
    echo "Package: ${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
    echo ""
    echo "To install:"
    echo "  sudo apt install ./${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
    echo ""
    echo "Or use:"
    echo "  ./build.sh install"
}

install_package() {
    if [ ! -f "${PACKAGE_NAME}_${VERSION}_${ARCH}.deb" ]; then
        echo "Package not found. Building first..."
        build
    fi

    echo ""
    echo "Installing ${PACKAGE_NAME}..."

    if [ "$EUID" -ne 0 ]; then
        echo "Installation requires root privileges"
        sudo apt install "./${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
    else
        apt install "./${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
    fi

    echo ""
    echo "Installation complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Copy your root CA to /etc/step/certs/root_ca.crt"
    echo "  2. Create a config in /etc/step-certctl/<name>.conf"
    echo "  3. Run: step-certctl issue <name>"
    echo "  4. Run: step-certctl install-timer <name>"
}

verify_package() {
    if [ ! -f "${PACKAGE_NAME}_${VERSION}_${ARCH}.deb" ]; then
        echo "Package not found. Build it first with: ./build.sh build"
        return 1
    fi

    echo "Verifying package contents..."
    dpkg-deb --contents "${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"

    echo ""
    echo "Package info:"
    dpkg-deb --info "${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
}

main() {
    local command="${1:-build}"

    case "${command}" in
        build)
            build
            ;;
        install)
            install_package
            ;;
        clean)
            clean
            ;;
        verify)
            verify_package
            ;;
        help|-h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown command: ${command}"
            echo ""
            usage
            exit 1
            ;;
    esac
}

main "$@"
