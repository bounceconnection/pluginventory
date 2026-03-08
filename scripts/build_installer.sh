#!/usr/bin/env bash
# build_installer.sh — Build PluginUpdater.app and produce a double-clickable .pkg installer
#
# Usage:
#   ./scripts/build_installer.sh [--version X.Y.Z] [--sign "Developer ID Installer: ..."]
#
# Output:
#   build/PluginUpdater-<version>.pkg
#
# Requirements:
#   xcodegen  — to regenerate the Xcode project
#   xcodebuild — bundled with Xcode / Xcode Command Line Tools
#   pkgbuild   — bundled with macOS
#   productbuild — bundled with macOS

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="$REPO_ROOT/PluginUpdater"
XCPROJECT="$PROJECT_DIR/PluginUpdater.xcodeproj"
SCHEME="PluginUpdater"
CONFIGURATION="Release"
BUILD_DIR="$REPO_ROOT/build"
INSTALLER_SCRIPTS_DIR="$SCRIPT_DIR/installer_scripts"
DISTRIBUTION_XML="$SCRIPT_DIR/distribution.xml"
VERSION="1.0.0"
SIGN_IDENTITY=""        # e.g. "Developer ID Installer: Acme Corp (TEAMID)"
APP_SIGN_IDENTITY=""    # e.g. "Developer ID Application: Acme Corp (TEAMID)"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)  VERSION="$2"; shift 2 ;;
    --sign)     SIGN_IDENTITY="$2"; shift 2 ;;
    --app-sign) APP_SIGN_IDENTITY="$2"; shift 2 ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--version X.Y.Z] [--sign 'Developer ID Installer: ...'] [--app-sign 'Developer ID Application: ...']" >&2
      exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
require() {
  if ! command -v "$1" &>/dev/null; then
    echo "ERROR: '$1' is not installed or not on PATH." >&2
    exit 1
  fi
}

step() { echo ""; echo "▶ $*"; }

# ---------------------------------------------------------------------------
# Prerequisite checks
# ---------------------------------------------------------------------------
step "Checking prerequisites"
require xcodebuild
require pkgbuild
require productbuild

if command -v xcodegen &>/dev/null; then
  HAS_XCODEGEN=1
else
  HAS_XCODEGEN=0
  echo "  xcodegen not found — skipping project regeneration (using existing .xcodeproj)"
fi

# ---------------------------------------------------------------------------
# Regenerate Xcode project
# ---------------------------------------------------------------------------
if [[ "$HAS_XCODEGEN" -eq 1 ]]; then
  step "Regenerating Xcode project with xcodegen"
  (cd "$PROJECT_DIR" && xcodegen generate --quiet)
fi

# ---------------------------------------------------------------------------
# Build the app
# ---------------------------------------------------------------------------
ARCHIVE_PATH="$BUILD_DIR/PluginUpdater.xcarchive"
step "Building $SCHEME ($CONFIGURATION) → archive at $ARCHIVE_PATH"
mkdir -p "$BUILD_DIR"

ARCHIVE_ARGS=(
  -project "$XCPROJECT"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -archivePath "$ARCHIVE_PATH"
  -destination "generic/platform=macOS"
  archive
  MARKETING_VERSION="$VERSION"
)

if [[ -n "$APP_SIGN_IDENTITY" ]]; then
  ARCHIVE_ARGS+=(CODE_SIGN_IDENTITY="$APP_SIGN_IDENTITY" CODE_SIGN_STYLE=Manual)
else
  ARCHIVE_ARGS+=(CODE_SIGN_STYLE=Automatic)
fi

xcodebuild "${ARCHIVE_ARGS[@]}"

# ---------------------------------------------------------------------------
# Export the app from the archive
# ---------------------------------------------------------------------------
EXPORT_DIR="$BUILD_DIR/export"
EXPORT_OPTIONS="$BUILD_DIR/ExportOptions.plist"
step "Exporting app from archive"

if [[ -n "$APP_SIGN_IDENTITY" ]]; then
  METHOD="developer-id"
else
  METHOD="mac-application"
fi

cat > "$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>${METHOD}</string>
  <key>destination</key>
  <string>export</string>
</dict>
</plist>
PLIST

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -exportPath "$EXPORT_DIR"

APP_PATH="$EXPORT_DIR/PluginUpdater.app"
if [[ ! -d "$APP_PATH" ]]; then
  # Some export paths include a subdirectory named after the scheme
  APP_PATH="$(find "$EXPORT_DIR" -name "PluginUpdater.app" -maxdepth 2 | head -1)"
fi

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "ERROR: Could not find PluginUpdater.app in export directory." >&2
  exit 1
fi
echo "  App located at: $APP_PATH"

# ---------------------------------------------------------------------------
# Stage app for pkgbuild
# ---------------------------------------------------------------------------
STAGING_DIR="$BUILD_DIR/pkg_root"
APP_INSTALL_DIR="$STAGING_DIR/Applications"
step "Staging app bundle"
rm -rf "$STAGING_DIR"
mkdir -p "$APP_INSTALL_DIR"
cp -R "$APP_PATH" "$APP_INSTALL_DIR/"

# ---------------------------------------------------------------------------
# Create component package (.pkg)
# ---------------------------------------------------------------------------
COMPONENT_PKG="$BUILD_DIR/PluginUpdater-component.pkg"
step "Creating component package with pkgbuild"

PKGBUILD_ARGS=(
  --root "$STAGING_DIR"
  --identifier "com.tomioueda.PluginUpdater"
  --version "$VERSION"
  --install-location "/"
  "$COMPONENT_PKG"
)

if [[ -n "$SIGN_IDENTITY" ]]; then
  PKGBUILD_ARGS=(--sign "$SIGN_IDENTITY" "${PKGBUILD_ARGS[@]}")
fi

if [[ -d "$INSTALLER_SCRIPTS_DIR" ]]; then
  PKGBUILD_ARGS=(--scripts "$INSTALLER_SCRIPTS_DIR" "${PKGBUILD_ARGS[@]}")
fi

pkgbuild "${PKGBUILD_ARGS[@]}"

# ---------------------------------------------------------------------------
# Create distribution installer (.pkg)
# ---------------------------------------------------------------------------
OUTPUT_PKG="$BUILD_DIR/PluginUpdater-${VERSION}.pkg"
step "Creating distribution package with productbuild"

PRODUCTBUILD_ARGS=(
  --distribution "$DISTRIBUTION_XML"
  --package-path "$BUILD_DIR"
  --resources "$SCRIPT_DIR/installer_resources"
  "$OUTPUT_PKG"
)

if [[ ! -d "$SCRIPT_DIR/installer_resources" ]]; then
  # No custom resources needed — productbuild can work without them
  PRODUCTBUILD_ARGS=(
    --distribution "$DISTRIBUTION_XML"
    --package-path "$BUILD_DIR"
    "$OUTPUT_PKG"
  )
fi

if [[ -n "$SIGN_IDENTITY" ]]; then
  PRODUCTBUILD_ARGS=(--sign "$SIGN_IDENTITY" "${PRODUCTBUILD_ARGS[@]}")
fi

productbuild "${PRODUCTBUILD_ARGS[@]}"

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
step "Done!"
echo ""
echo "  Installer: $OUTPUT_PKG"
echo ""
echo "  To distribute without notarization (for local use / testing):"
echo "    open '$OUTPUT_PKG'"
echo ""
echo "  To notarize for public distribution:"
echo "    xcrun notarytool submit '$OUTPUT_PKG' --apple-id YOU@example.com --team-id TEAMID --password APP_SPECIFIC_PASSWORD --wait"
echo "    xcrun stapler staple '$OUTPUT_PKG'"
