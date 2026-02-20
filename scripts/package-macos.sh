#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="SpendyTime"
BUILD_DIR="${ROOT_DIR}/build"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
INFO_PLIST="${ROOT_DIR}/Resources/Info.plist"
EXECUTABLE="${ROOT_DIR}/.build/release/${APP_NAME}"
VERSION="${VERSION:-}"
ICON_PATH="${ICON_PATH:-}"
CREATE_DMG=false

usage() {
  cat <<'USAGE'
Usage: ./scripts/package-macos.sh [options]

Options:
  --version <semver>   Override app version (CFBundleVersion / CFBundleShortVersionString)
  --icon <png>         Path to a 1024x1024 PNG to generate AppIcon.icns
  --dmg                Create a SpendyTime.dmg in build/

Environment:
  SIGN_IDENTITY        Code signing identity (Developer ID Application: ...)
  VERSION              Same as --version
  ICON_PATH            Same as --icon
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="${2:-}"
      shift 2
      ;;
    --icon)
      ICON_PATH="${2:-}"
      shift 2
      ;;
    --dmg)
      CREATE_DMG=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

echo "Building release binary..."
cd "${ROOT_DIR}"
swift build -c release

echo "Creating .app bundle..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
cp "${EXECUTABLE}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
cp "${INFO_PLIST}" "${APP_DIR}/Contents/Info.plist"

chmod +x "${APP_DIR}/Contents/MacOS/${APP_NAME}"

if [[ -n "${VERSION}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "${APP_DIR}/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${APP_DIR}/Contents/Info.plist"
fi

if [[ -n "${ICON_PATH}" ]]; then
  if [[ ! -f "${ICON_PATH}" ]]; then
    echo "Icon not found: ${ICON_PATH}"
    exit 1
  fi
  echo "Generating AppIcon.icns from ${ICON_PATH}"
  ICONSET_DIR="${BUILD_DIR}/AppIcon.iconset"
  rm -rf "${ICONSET_DIR}"
  mkdir -p "${ICONSET_DIR}"
  sips -z 16 16     "${ICON_PATH}" --out "${ICONSET_DIR}/icon_16x16.png" >/dev/null
  sips -z 32 32     "${ICON_PATH}" --out "${ICONSET_DIR}/icon_16x16@2x.png" >/dev/null
  sips -z 32 32     "${ICON_PATH}" --out "${ICONSET_DIR}/icon_32x32.png" >/dev/null
  sips -z 64 64     "${ICON_PATH}" --out "${ICONSET_DIR}/icon_32x32@2x.png" >/dev/null
  sips -z 128 128   "${ICON_PATH}" --out "${ICONSET_DIR}/icon_128x128.png" >/dev/null
  sips -z 256 256   "${ICON_PATH}" --out "${ICONSET_DIR}/icon_128x128@2x.png" >/dev/null
  sips -z 256 256   "${ICON_PATH}" --out "${ICONSET_DIR}/icon_256x256.png" >/dev/null
  sips -z 512 512   "${ICON_PATH}" --out "${ICONSET_DIR}/icon_256x256@2x.png" >/dev/null
  sips -z 512 512   "${ICON_PATH}" --out "${ICONSET_DIR}/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "${ICON_PATH}" --out "${ICONSET_DIR}/icon_512x512@2x.png" >/dev/null
  iconutil -c icns "${ICONSET_DIR}" -o "${APP_DIR}/Contents/Resources/AppIcon.icns"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "${APP_DIR}/Contents/Info.plist" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "${APP_DIR}/Contents/Info.plist"
fi

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  echo "Codesigning with identity: ${SIGN_IDENTITY}"
  codesign --force --options runtime --timestamp --sign "${SIGN_IDENTITY}" "${APP_DIR}"
else
  echo "Skipping codesign (SIGN_IDENTITY not set)."
fi

if [[ "${CREATE_DMG}" == "true" ]]; then
  DMG_PATH="${BUILD_DIR}/${APP_NAME}.dmg"
  echo "Creating DMG: ${DMG_PATH}"
  hdiutil create -volname "${APP_NAME}" -srcfolder "${APP_DIR}" -ov -format UDZO "${DMG_PATH}" >/dev/null
fi

echo "Done: ${APP_DIR}"
