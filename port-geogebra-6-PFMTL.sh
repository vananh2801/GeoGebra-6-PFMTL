#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Ports GeoGebra Classic 6 from a Windows Portable .zip onto Linux by
downloading the exact matching official Electron shell from GitHub.

RECOMMENDED USAGE:
  ./port-geogebra-6-PFMTL.sh --win GeoGebra-Windows-Portable-X-Y-Z.zip
  ./port-geogebra-6-PFMTL.sh --win GeoGebra-Windows-Portable-X-Y-Z.zip --install
  ./port-geogebra-6-PFMTL.sh --win GeoGebra-Windows-Portable-X-Y-Z.zip --format none --install

Options:
  --electron-shell auto                (default) downloads Electron from GitHub
  --electron-shell /path/to/file.zip   uses Electron from electron-vX.Y.Z-linux-x64.zip
  --format zip                         (default) create installer and packaging into .zip
  --format none                        skip packaging, only useful with --install
  --install                            also install the GeoGebra on this machine now

Github: https://github.com/vananh2801/GeoGebra-6-PFMTL

Requirement: curl, zip, unzip

USAGE
}

c_info()  { printf '\033[1;34m[i]\033[0m %s\n' "$1"; }
c_ok()    { printf '\033[1;32m[+]\033[0m %s\n' "$1"; }
c_warn()  { printf '\033[1;33m[!]\033[0m %s\n' "$1"; }
c_err()   { printf '\033[1;31m[x]\033[0m %s\n' "$1" >&2; }
die()     { c_err "$1"; exit 1; }

WIN_ZIP=""
ELECTRON_SHELL="auto"
FORMAT="zip"
OUTPUT_DIR="$(pwd)"
DO_INSTALL=0
INSTALL_DIR="${HOME}/.local/share/GeoGebra"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --win) WIN_ZIP="$2"; shift 2 ;;
    --electron-shell) ELECTRON_SHELL="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --install) DO_INSTALL=1; shift ;;
    --help) usage; exit 0 ;;
    *) die "Không hiểu tham số: $1" ;;
  esac
done
[[ -n "$WIN_ZIP" && -f "$WIN_ZIP" ]] || die "Thiếu hoặc không tìm thấy --win <file.zip bản Windows Portable>."
[[ "$FORMAT" == "zip" || "$FORMAT" == "none" ]] || die "--format phải là 'zip' hoặc 'none'."
command -v unzip >/dev/null 2>&1 || die "Cần lệnh 'unzip'."
[[ "$FORMAT" == "zip" ]] && { command -v zip >/dev/null 2>&1 || die "Cần lệnh 'zip' để đóng gói (--format zip)."; }
mkdir -p "$OUTPUT_DIR"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ---------- 1. Giải nén bản Windows, tìm resources/app ----------
c_info "Giải nén bản Windows..."
mkdir -p "$WORK/win"
unzip -q "$WIN_ZIP" -d "$WORK/win"
WIN_APP="$(find "$WORK/win" -type d -path '*resources/app' -not -path '*node_modules*' | head -n1)"
[[ -n "$WIN_APP" && -f "$WIN_APP/main.js" ]] || die "Không tìm thấy resources/app hợp lệ trong file Windows."
c_ok "Nội dung Windows: $WIN_APP"

VERSION="$(basename "$WIN_ZIP" | grep -oE '[0-9]+-[0-9]+-[0-9]+-[0-9]+' | tr '-' '.' | head -n1)"
[[ -n "$VERSION" ]] || VERSION="unknown"
c_ok "Phiên bản GeoGebra: $VERSION"

# ---------- 2. Xác định & tải đúng bản Electron chính chủ ----------
STAGE="$WORK/stage"; mkdir -p "$STAGE"
ELECTRON_ZIP=""; EVER="thư mục/zip do bạn cung cấp"
if [[ "$ELECTRON_SHELL" == "auto" ]]; then
  EVER="$(grep -oE '"electron"\s*:\s*"[^"]+"' "$WIN_APP/package.json" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
  [[ -n "$EVER" ]] || die "Không đọc được version electron từ package.json. Dùng --electron-shell <file.zip> đã tải sẵn thay vì 'auto'."
  c_info "GeoGebra $VERSION dùng Electron $EVER -> tải bản Linux x64 chính chủ..."
  URL="https://github.com/electron/electron/releases/download/v${EVER}/electron-v${EVER}-linux-x64.zip"
  ELECTRON_ZIP="$WORK/electron-${EVER}-linux-x64.zip"
  command -v curl >/dev/null 2>&1 || die "Cần lệnh 'curl' để tải Electron tự động."
  curl -fL --progress-bar "$URL" -o "$ELECTRON_ZIP" || die "Tải Electron $EVER thất bại. Kiểm tra mạng hoặc dùng --electron-shell <file.zip>."
elif [[ -f "$ELECTRON_SHELL" ]]; then
  ELECTRON_ZIP="$ELECTRON_SHELL"
else
  die "--electron-shell phải là 'auto' hoặc đường dẫn tới file electron-vX.Y.Z-linux-x64.zip."
fi

c_info "Dựng vỏ Electron..."
unzip -q "$ELECTRON_ZIP" -d "$STAGE"
[[ -f "$STAGE/electron" ]] || die "Zip Electron không hợp lệ (thiếu file thực thi 'electron')."
rm -f "$STAGE/resources/default_app.asar"
mv "$STAGE/electron" "$STAGE/GeoGebra"

# ---------- 3. Copy thẳng resources/app từ Windows vào (không cần merge) ----------
c_info "Copy resources/app từ bản Windows..."
rm -rf "$STAGE/resources/app"
cp -a "$WIN_APP" "$STAGE/resources/app"

chmod +x "$STAGE/GeoGebra"
[[ -f "$STAGE/chrome-sandbox" ]] && chmod +x "$STAGE/chrome-sandbox" || true
[[ -f "$STAGE/chrome_crashpad_handler" ]] && chmod +x "$STAGE/chrome_crashpad_handler" || true
c_ok "Đã dựng xong bản Linux từ nguồn Windows."

# ---------- 4. Icon ----------
ICON_PNG="./resources/geogebra.png"

# ---------- 5. Đóng gói .zip (kèm install.sh / uninstall.sh) ----------
ZIP_OUT=""
if [[ "$FORMAT" == "zip" ]]; then
  PKG_NAME="GeoGebra-Linux-Portable-${VERSION}"
  PKG_DIR="$WORK/pkg/$PKG_NAME"
  mkdir -p "$PKG_DIR"
  cp -a "$STAGE" "$PKG_DIR/app"
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
chmod +x "\$INSTALL_DIR/GeoGebra"

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
exec "\$INSTALL_DIR/GeoGebra" "\\\$@"
LAUNCHER
chmod +x "\$BIN_DIR/geogebra"

ICON_LINE="Icon=accessories-calculator"
if [[ -f "\$HERE/geogebra.png" ]]; then
  cp "\$HERE/geogebra.png" "\$ICON_DIR/geogebra.png"
  ICON_LINE="Icon=\$ICON_DIR/geogebra.png"
fi

cat > "\$DESKTOP_DIR/geogebra.desktop" <<DESKTOP
[Desktop Entry]
Version=${VERSION}
Type=Application
Name=GeoGebra Classic 6
Comment=Dynamic mathematics software
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

  ZIP_OUT="$OUTPUT_DIR/${PKG_NAME}.zip"
  ( cd "$WORK/pkg" && zip -qr "$ZIP_OUT" "$PKG_NAME" )
  c_ok "Đã tạo: $ZIP_OUT"
fi

# ---------- 6. Cài luôn nếu có --install ----------
if [[ "$DO_INSTALL" -eq 1 ]]; then
  c_info "Cài vào máy này..."
  if [[ -n "$ZIP_OUT" ]]; then
    TMP_EXTRACT="$WORK/install-extract"; mkdir -p "$TMP_EXTRACT"
    unzip -q "$ZIP_OUT" -d "$TMP_EXTRACT"
    bash "$TMP_EXTRACT/$(basename "$ZIP_OUT" .zip)/install.sh" "$INSTALL_DIR"
  else
    # --format none: cài thẳng từ STAGE, không qua bước đóng gói
    TMP_PKG="$WORK/direct-install"; mkdir -p "$TMP_PKG"
    cp -a "$STAGE" "$TMP_PKG/app"
    [[ -n "$ICON_PNG" ]] && cp "$ICON_PNG" "$TMP_PKG/geogebra.png"
    cat > "$TMP_PKG/install.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
HERE="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="\${1:-\$HOME/.local/share/GeoGebra}"
BIN_DIR="\$HOME/.local/bin"; DESKTOP_DIR="\$HOME/.local/share/applications"; ICON_DIR="\$HOME/.local/share/icons"
mkdir -p "\$BIN_DIR" "\$DESKTOP_DIR" "\$ICON_DIR"
rm -rf "\$INSTALL_DIR"; cp -a "\$HERE/app" "\$INSTALL_DIR"; chmod +x "\$INSTALL_DIR/GeoGebra"

SANDBOX_OK=0
if [[ -f "\$INSTALL_DIR/chrome-sandbox" ]]; then
  sudo -n chown root:root "\$INSTALL_DIR/chrome-sandbox" 2>/dev/null && sudo -n chmod 4755 "\$INSTALL_DIR/chrome-sandbox" 2>/dev/null && SANDBOX_OK=1
fi
ENV_LINE=""; [[ "\$SANDBOX_OK" -eq 0 ]] && ENV_LINE='export ELECTRON_DISABLE_SANDBOX=1'
cat > "\$BIN_DIR/geogebra" <<LAUNCHER
#!/usr/bin/env bash
\$ENV_LINE
exec "\$INSTALL_DIR/GeoGebra" "\\\$@"
LAUNCHER
chmod +x "\$BIN_DIR/geogebra"

ICON_LINE="Icon=accessories-calculator"
[[ -f "\$HERE/geogebra.png" ]] && cp "\$HERE/geogebra.png" "\$ICON_DIR/geogebra.png" && ICON_LINE="Icon=\$ICON_DIR/geogebra.png"

cat > "\$DESKTOP_DIR/geogebra.desktop" <<DESKTOP
[Desktop Entry]
Version=${VERSION}
Type=Application
Name=GeoGebra Classic 6
Exec=\$BIN_DIR/geogebra %F
Terminal=false
Categories=Education;Science;Math;
\$ICON_LINE
DESKTOP
chmod +x "\$DESKTOP_DIR/geogebra.desktop"
echo "Cài xong tại \$INSTALL_DIR."
EOF
    chmod +x "$TMP_PKG/install.sh"
    bash "$TMP_PKG/install.sh" "$INSTALL_DIR"
  fi
  c_ok "Đã cài xong. Chạy bằng lệnh: geogebra"
fi

if [[ -z "$ZIP_OUT" && "$DO_INSTALL" -eq 0 ]]; then
  c_warn "Không đóng gói (--format none) và không cài (--install) - không có gì được tạo ra cả."
fi
