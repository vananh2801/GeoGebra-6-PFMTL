#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Ports GeoGebra content from a macOS Portable .zip (optionally swapping
in the matching official Electron shell), then PACKAGES the result into
distributable files instead of installing directly:
  - geogebra-classic-6_<version>_amd64.deb   (Debian/Ubuntu - recommended)
  - geogebra-classic-6-<version>-linux-x64.tar.gz + install.sh/uninstall.sh
    (works on any Linux x64 distro)

Build once here, then copy the .deb (or .tar.gz) to any machine and
install it there - no need to redo the port or re-download Electron.

USAGE:
  ./build-geogebra-package.sh --mac MAC.zip --base LINUX.zip --electron-shell auto
  ./build-geogebra-package.sh --mac MAC.zip --electron-shell auto   # reuses ~/.local/share/GeoGebra as base
  ./build-geogebra-package.sh --mac MAC.zip --electron-shell auto --install   # also install right now

Options:
  --format deb|tar|both   (default: both)
  --output-dir DIR        (default: current directory)
  --install               after building, also install the package on THIS machine
                           (uses .deb via sudo apt if available, else the .tar.gz install.sh)
USAGE
}

c_info()  { printf '\033[1;34m[i]\033[0m %s\n' "$1"; }
c_ok()    { printf '\033[1;32m[+]\033[0m %s\n' "$1"; }
c_warn()  { printf '\033[1;33m[!]\033[0m %s\n' "$1"; }
c_err()   { printf '\033[1;31m[x]\033[0m %s\n' "$1" >&2; }
die()     { c_err "$1"; exit 1; }

MAC_ZIP=""; BASE_ARG=""; ELECTRON_SHELL="skip"; FORMAT="both"; DO_INSTALL=0
OUTPUT_DIR="$(pwd)"
INSTALL_DIR_HINT="${HOME}/.local/share/GeoGebra"   # only used to find a base if --base omitted

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mac) MAC_ZIP="$2"; shift 2 ;;
    --base) BASE_ARG="$2"; shift 2 ;;
    --electron-shell) ELECTRON_SHELL="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --install) DO_INSTALL=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Không hiểu tham số: $1" ;;
  esac
done
# --install cần ít nhất 1 định dạng thực sự cài được sẵn có
if [[ "$DO_INSTALL" -eq 1 && "$FORMAT" == "deb" ]] && ! command -v dpkg-deb >/dev/null 2>&1; then
  die "--install với --format deb cần có dpkg-deb trên máy này."
fi
[[ -n "$MAC_ZIP" && -f "$MAC_ZIP" ]] || die "Thiếu hoặc không tìm thấy --mac <file.zip>."
command -v unzip >/dev/null 2>&1 || die "Cần lệnh 'unzip'."
mkdir -p "$OUTPUT_DIR"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ---------- 1. Vỏ Linux nền (lấy node_modules native) ----------
BASE_DIR=""
if [[ -n "$BASE_ARG" ]]; then
  if [[ -d "$BASE_ARG" ]]; then BASE_DIR="$BASE_ARG"
  elif [[ -f "$BASE_ARG" ]]; then mkdir -p "$WORK/base"; unzip -q "$BASE_ARG" -d "$WORK/base"; BASE_DIR="$WORK/base"
  else die "Không tìm thấy --base: $BASE_ARG"; fi
elif [[ -d "$INSTALL_DIR_HINT" ]]; then
  BASE_DIR="$INSTALL_DIR_HINT"; c_info "Không có --base, dùng bản đã cài tại $INSTALL_DIR_HINT."
else
  die "Chưa có bản Linux nào để lấy node_modules gốc. Cần --base <GeoGebra-Linux64-Portable-....zip> ít nhất 1 lần."
fi
LINUX_ROOT="$(find "$BASE_DIR" -maxdepth 2 -type d -iname 'GeoGebra-linux-x64' | head -n1)"; [[ -n "$LINUX_ROOT" ]] || LINUX_ROOT="$BASE_DIR"
LINUX_APP="$(find "$LINUX_ROOT" -type d -path '*resources/app' -not -path '*node_modules*' | head -n1)"
[[ -n "$LINUX_APP" ]] || die "Không tìm thấy resources/app trong bản Linux nền."

# ---------- 2. Nội dung macOS ----------
mkdir -p "$WORK/mac"; unzip -q "$MAC_ZIP" -d "$WORK/mac"
MAC_APP_BUNDLE="$(find "$WORK/mac" -maxdepth 1 -type d -iname '*.app' | head -n1)"; [[ -n "$MAC_APP_BUNDLE" ]] || die "Không tìm thấy .app trong file macOS."
MAC_APP="$(find "$MAC_APP_BUNDLE" -type d -path '*Resources/app' -not -path '*node_modules*' | head -n1)"
[[ -n "$MAC_APP" && -f "$MAC_APP/main.js" ]] || die "resources/app trong bản macOS không hợp lệ."
VERSION="$(basename "$MAC_ZIP" | grep -oE '[0-9]+-[0-9]+-[0-9]+-[0-9]+' | tr '-' '.' | head -n1)"; [[ -n "$VERSION" ]] || VERSION="0.0.0.0"
c_ok "Nội dung macOS: phiên bản $VERSION"

# ---------- 3. Dựng bản đã ghép (giống v2, nhưng đóng gói thay vì cài) ----------
STAGE="$WORK/stage"; mkdir -p "$STAGE"
if [[ "$ELECTRON_SHELL" == "skip" ]]; then
  cp -a "$LINUX_ROOT/." "$STAGE/"
else
  ELECTRON_ZIP=""; EVER="thư mục/zip do bạn cung cấp"
  if [[ "$ELECTRON_SHELL" == "auto" ]]; then
    EVER="$(grep -oE '"electron"\s*:\s*"[^"]+"' "$MAC_APP/package.json" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
    [[ -n "$EVER" ]] || die "Không đọc được version electron, dùng --electron-shell <file.zip> đã tải sẵn."
    c_info "Tải Electron $EVER (linux-x64) chính chủ..."
    URL="https://github.com/electron/electron/releases/download/v${EVER}/electron-v${EVER}-linux-x64.zip"
    ELECTRON_ZIP="$WORK/electron-${EVER}.zip"
    command -v curl >/dev/null 2>&1 || die "Cần 'curl' để tải Electron tự động."
    curl -fL --progress-bar "$URL" -o "$ELECTRON_ZIP" || die "Tải Electron $EVER thất bại."
  elif [[ -f "$ELECTRON_SHELL" ]]; then ELECTRON_ZIP="$ELECTRON_SHELL"
  else die "--electron-shell phải là 'auto', 'skip', hoặc đường dẫn file zip electron."; fi
  unzip -q "$ELECTRON_ZIP" -d "$STAGE"
  [[ -f "$STAGE/electron" ]] || die "Zip Electron không hợp lệ."
  rm -f "$STAGE/resources/default_app.asar"
  mkdir -p "$STAGE/resources/app"
  cp -a "$LINUX_APP/node_modules" "$STAGE/resources/app/node_modules"
  cp "$LINUX_APP/package.json" "$STAGE/resources/app/package.json"
  mv "$STAGE/electron" "$STAGE/GeoGebra"
  c_ok "Đã dựng vỏ Electron $EVER."
fi
STAGE_APP="$(find "$STAGE" -type d -path '*resources/app' -not -path '*node_modules*' | head -n1)"
[[ -n "$STAGE_APP" ]] || die "Lỗi nội bộ: không thấy resources/app trong bản dựng."

rm -rf "$STAGE_APP/html"; cp -r "$MAC_APP/html" "$STAGE_APP/html"
cp "$MAC_APP/main.js" "$STAGE_APP/main.js"
cp "$MAC_APP/preload.js" "$STAGE_APP/preload.js"
[[ -f "$MAC_APP/ggb-config.js" ]] && cp "$MAC_APP/ggb-config.js" "$STAGE_APP/ggb-config.js"
[[ -f "$STAGE/version" ]] && echo -n "$VERSION" > "$STAGE/version"

MAIN_BIN_NAME="$(find "$STAGE" -maxdepth 1 -type f -perm -u+x ! -name '*.so*' ! -iname '*.pak' | grep -v 'chrome_crashpad_handler\|chrome-sandbox' | xargs -n1 basename | head -n1)"
[[ -n "$MAIN_BIN_NAME" ]] || die "Không tìm thấy file thực thi chính."
chmod +x "$STAGE/$MAIN_BIN_NAME"
[[ -f "$STAGE/chrome-sandbox" ]] && chmod +x "$STAGE/chrome-sandbox" || true
[[ -f "$STAGE/chrome_crashpad_handler" ]] && chmod +x "$STAGE/chrome_crashpad_handler" || true

# icon (best effort)
ICON_PNG=""
ICNS_SRC="$(find "$MAC_APP_BUNDLE" -maxdepth 3 -iname '*.icns' | head -n1)"
if [[ -n "$ICNS_SRC" ]] && command -v python3 >/dev/null 2>&1 && python3 -c "import PIL" >/dev/null 2>&1; then
  if python3 - "$ICNS_SRC" "$WORK/geogebra.png" <<'PYEOF'
import sys
from PIL import Image
Image.open(sys.argv[1]).save(sys.argv[2])
PYEOF
  then ICON_PNG="$WORK/geogebra.png"; fi
fi

c_ok "Đã ghép xong nội dung phiên bản $VERSION. Bắt đầu đóng gói..."

# ---------- 4a. Gói .tar.gz portable (kèm install.sh / uninstall.sh) ----------
build_tar() {
  local PKG_NAME="geogebra-classic-6-${VERSION}-linux-x64"
  local PKG_DIR="$WORK/pkg-tar/$PKG_NAME"
  mkdir -p "$PKG_DIR"
  cp -a "$STAGE/." "$PKG_DIR/app"
  [[ -n "$ICON_PNG" ]] && cp "$ICON_PNG" "$PKG_DIR/geogebra.png"

  cat > "$PKG_DIR/install.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
HERE="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="\${1:-\$HOME/.local/share/GeoGebra}"
BIN_DIR="\$HOME/.local/bin"
DESKTOP_DIR="\$HOME/.local/share/applications"
ICON_DIR="\$HOME/.local/share/icons"
mkdir -p "\$BIN_DIR" "\$DESKTOP_DIR" "\$ICON_DIR"
rm -rf "\$INSTALL_DIR"
cp -a "\$HERE/app" "\$INSTALL_DIR"
chmod +x "\$INSTALL_DIR/${MAIN_BIN_NAME}"

SANDBOX_OK=0
if [[ -f "\$INSTALL_DIR/chrome-sandbox" ]]; then
  if sudo -n chown root:root "\$INSTALL_DIR/chrome-sandbox" 2>/dev/null && \\
     sudo -n chmod 4755 "\$INSTALL_DIR/chrome-sandbox" 2>/dev/null; then
    SANDBOX_OK=1
  fi
fi
ENV_LINE=""
[[ "\$SANDBOX_OK" -eq 0 ]] && ENV_LINE='export ELECTRON_DISABLE_SANDBOX=1'
cat > "\$BIN_DIR/geogebra" <<LAUNCHER
#!/usr/bin/env bash
\$ENV_LINE
exec "\$INSTALL_DIR/${MAIN_BIN_NAME}" "\\\$@"
LAUNCHER
chmod +x "\$BIN_DIR/geogebra"

[[ -f "\$HERE/geogebra.png" ]] && cp "\$HERE/geogebra.png" "\$ICON_DIR/geogebra.png"
ICON_LINE="Icon=accessories-calculator"
[[ -f "\$ICON_DIR/geogebra.png" ]] && ICON_LINE="Icon=\$ICON_DIR/geogebra.png"

cat > "\$DESKTOP_DIR/geogebra.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=GeoGebra Classic 6
Comment=Dynamic mathematics software (v${VERSION})
Exec=\$BIN_DIR/geogebra %F
Terminal=false
Categories=Education;Science;Math;
\$ICON_LINE
DESKTOP
chmod +x "\$DESKTOP_DIR/geogebra.desktop"

echo "Cài xong tại \$INSTALL_DIR. Chạy bằng lệnh: geogebra"
[[ "\$SANDBOX_OK" -eq 0 ]] && echo "(Sandbox chưa bật được, launcher tự dùng ELECTRON_DISABLE_SANDBOX=1)"
EOF
  chmod +x "$PKG_DIR/install.sh"

  cat > "$PKG_DIR/uninstall.sh" <<'EOF'
#!/usr/bin/env bash
set -e
rm -rf "$HOME/.local/share/GeoGebra"
rm -f "$HOME/.local/bin/geogebra"
rm -f "$HOME/.local/share/applications/geogebra.desktop"
rm -f "$HOME/.local/share/icons/geogebra.png"
echo "Đã gỡ GeoGebra."
EOF
  chmod +x "$PKG_DIR/uninstall.sh"

  ( cd "$WORK/pkg-tar" && tar -czf "$OUTPUT_DIR/${PKG_NAME}.tar.gz" "$PKG_NAME" )
  TAR_OUT="$OUTPUT_DIR/${PKG_NAME}.tar.gz"
  TAR_PKG_DIRNAME="$PKG_NAME"
  c_ok "Đã tạo: $TAR_OUT"
}

# ---------- 4b. Gói .deb (khuyên dùng trên Debian/Ubuntu) ----------
build_deb() {
  command -v dpkg-deb >/dev/null 2>&1 || { c_warn "Không có dpkg-deb, bỏ qua bản .deb."; return; }
  local DEBVER; DEBVER="$(echo "$VERSION" | sed 's/[^0-9.]//g')"; [[ -n "$DEBVER" ]] || DEBVER="0.0.0"
  local ROOT="$WORK/pkg-deb"
  mkdir -p "$ROOT/DEBIAN" "$ROOT/opt/geogebra" "$ROOT/usr/bin" "$ROOT/usr/share/applications" "$ROOT/usr/share/icons/hicolor/256x256/apps"
  cp -a "$STAGE/." "$ROOT/opt/geogebra/"

  cat > "$ROOT/usr/bin/geogebra" <<EOF
#!/usr/bin/env bash
exec /opt/geogebra/${MAIN_BIN_NAME} "\$@"
EOF
  chmod 755 "$ROOT/usr/bin/geogebra"

  local ICON_LINE="Icon=accessories-calculator"
  if [[ -n "$ICON_PNG" ]]; then
    cp "$ICON_PNG" "$ROOT/usr/share/icons/hicolor/256x256/apps/geogebra.png"
    ICON_LINE="Icon=geogebra"
  fi
  cat > "$ROOT/usr/share/applications/geogebra.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=GeoGebra Classic 6
Comment=Dynamic mathematics software (v${VERSION})
Exec=/usr/bin/geogebra %F
Terminal=false
Categories=Education;Science;Math;
$ICON_LINE
EOF

  cat > "$ROOT/DEBIAN/control" <<EOF
Package: geogebra-classic-6-ported
Version: ${DEBVER}
Section: education
Priority: optional
Architecture: amd64
Maintainer: Local Build <local@localhost>
Description: GeoGebra Classic 6 (ported content, Electron shell ${ELECTRON_SHELL})
 Built locally by build-geogebra-package.sh: GeoGebra content from a
 macOS Portable release ported onto Linux, optionally with an upgraded
 official Electron runtime.
EOF

  cat > "$ROOT/DEBIAN/postinst" <<EOF
#!/bin/sh
set -e
chmod +x /opt/geogebra/${MAIN_BIN_NAME} || true
if [ -f /opt/geogebra/chrome-sandbox ]; then
  chown root:root /opt/geogebra/chrome-sandbox || true
  chmod 4755 /opt/geogebra/chrome-sandbox || true
fi
[ -f /opt/geogebra/chrome_crashpad_handler ] && chmod +x /opt/geogebra/chrome_crashpad_handler || true
update-desktop-database -q /usr/share/applications 2>/dev/null || true
exit 0
EOF
  chmod 755 "$ROOT/DEBIAN/postinst"

  local OUT_DEB="$OUTPUT_DIR/geogebra-classic-6_${DEBVER}_amd64.deb"
  dpkg-deb --root-owner-group --build "$ROOT" "$OUT_DEB" >/dev/null
  DEB_OUT="$OUT_DEB"
  c_ok "Đã tạo: $OUT_DEB"
}

DEB_OUT=""; TAR_OUT=""; TAR_PKG_DIRNAME=""

case "$FORMAT" in
  deb) build_deb ;;
  tar) build_tar ;;
  both) build_deb; build_tar ;;
  *) die "--format phải là deb, tar, hoặc both" ;;
esac

echo
c_ok "Xong. File đóng gói nằm trong: $OUTPUT_DIR"
[[ -n "$DEB_OUT" ]] && echo "  Cài bằng .deb:  sudo apt install ./$(basename "$DEB_OUT")"
[[ -n "$TAR_OUT" ]] && echo "  Cài bằng .tar.gz: giải nén rồi chạy ./install.sh bên trong"

# ---------- 5. Cài luôn nếu có --install ----------
if [[ "$DO_INSTALL" -eq 1 ]]; then
  echo
  if [[ -n "$DEB_OUT" ]] && command -v sudo >/dev/null 2>&1; then
    c_info "Cài bằng .deb (sudo apt install)..."
    if sudo apt install -y "$DEB_OUT"; then
      c_ok "Đã cài xong. Chạy bằng lệnh: geogebra"
    else
      c_warn "Cài .deb thất bại, thử phương án .tar.gz nếu có..."
      if [[ -n "$TAR_OUT" ]]; then
        TMP_EXTRACT="$WORK/install-extract"; mkdir -p "$TMP_EXTRACT"
        tar -xzf "$TAR_OUT" -C "$TMP_EXTRACT"
        bash "$TMP_EXTRACT/$TAR_PKG_DIRNAME/install.sh"
      else
        die "Không có bản .tar.gz để dự phòng. Chạy lại với --format both."
      fi
    fi
  elif [[ -n "$TAR_OUT" ]]; then
    c_info "Cài bằng .tar.gz (install.sh, không cần sudo)..."
    TMP_EXTRACT="$WORK/install-extract"; mkdir -p "$TMP_EXTRACT"
    tar -xzf "$TAR_OUT" -C "$TMP_EXTRACT"
    bash "$TMP_EXTRACT/$TAR_PKG_DIRNAME/install.sh"
  else
    die "Không có file nào để cài (kiểm tra lại --format)."
  fi
fi
