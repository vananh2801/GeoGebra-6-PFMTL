#!/usr/bin/env bash
#
# port-and-install-geogebra-v2.sh
#
# Ports GeoGebra Classic 6 content from a macOS Portable .zip onto Linux,
# and (optionally) swaps the Electron/Chromium "shell" itself for the
# exact official Electron build that the macOS content was written for.
# This closes the version gap between the old bundled Linux Electron
# (25.x) and whatever newer Electron the Mac build used.
#
# USAGE (first run, need the ORIGINAL Linux Portable zip once - it
# supplies the native node_modules that must stay Linux-x64 specific):
#   ./port-and-install-geogebra-v2.sh --mac MAC.zip --base LINUX.zip --electron-shell auto
#
# USAGE (later updates, reuse the installed copy as base):
#   ./port-and-install-geogebra-v2.sh --mac NEW_MAC.zip --electron-shell auto
#
# --electron-shell auto        download the exact Electron version declared
#                               in the Mac build's package.json (recommended)
# --electron-shell skip        keep whatever Electron shell is already there
#                               (same behavior as the v1 script)
# --electron-shell /path.zip   use a local official electron-vX.Y.Z-linux-x64.zip
#                               you already downloaded yourself
#
set -euo pipefail

c_info()  { printf '\033[1;34m[i]\033[0m %s\n' "$1"; }
c_ok()    { printf '\033[1;32m[+]\033[0m %s\n' "$1"; }
c_warn()  { printf '\033[1;33m[!]\033[0m %s\n' "$1"; }
c_err()   { printf '\033[1;31m[x]\033[0m %s\n' "$1" >&2; }
die()     { c_err "$1"; exit 1; }

MAC_ZIP=""
BASE_ARG=""
ELECTRON_SHELL="skip"
INSTALL_DIR="${HOME}/.local/share/GeoGebra"
BIN_DIR="${HOME}/.local/bin"
DESKTOP_DIR="${HOME}/.local/share/applications"
ICON_DIR="${HOME}/.local/share/icons"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mac) MAC_ZIP="$2"; shift 2 ;;
    --base) BASE_ARG="$2"; shift 2 ;;
    --electron-shell) ELECTRON_SHELL="$2"; shift 2 ;;
    --install-dir) INSTALL_DIR="$2"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^#//'; exit 0 ;;
    *) die "Không hiểu tham số: $1" ;;
  esac
done

[[ -n "$MAC_ZIP" && -f "$MAC_ZIP" ]] || die "Thiếu hoặc không tìm thấy --mac <file.zip>."
command -v unzip >/dev/null 2>&1 || die "Cần lệnh 'unzip'."

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ---------- 1. Vỏ Linux nền (để lấy node_modules native cho Linux x64) ----------
BASE_DIR=""
if [[ -n "$BASE_ARG" ]]; then
  if [[ -d "$BASE_ARG" ]]; then BASE_DIR="$BASE_ARG"
  elif [[ -f "$BASE_ARG" ]]; then
    mkdir -p "$WORK/base"; unzip -q "$BASE_ARG" -d "$WORK/base"; BASE_DIR="$WORK/base"
  else die "Không tìm thấy --base: $BASE_ARG"; fi
elif [[ -d "$INSTALL_DIR" ]]; then
  BASE_DIR="$INSTALL_DIR"
  c_info "Không có --base, dùng bản đã cài tại $INSTALL_DIR."
else
  die "Chưa có bản Linux nào để lấy node_modules gốc. Lần đầu cần --base <GeoGebra-Linux64-Portable-....zip>."
fi
LINUX_ROOT="$(find "$BASE_DIR" -maxdepth 2 -type d -iname 'GeoGebra-linux-x64' | head -n1)"
[[ -n "$LINUX_ROOT" ]] || LINUX_ROOT="$BASE_DIR"
LINUX_APP="$(find "$LINUX_ROOT" -type d -path '*resources/app' -not -path '*node_modules*' | head -n1)"
[[ -n "$LINUX_APP" ]] || die "Không tìm thấy resources/app trong bản Linux nền."
c_ok "Vỏ Linux nền: $LINUX_ROOT"

# ---------- 2. Nội dung macOS mới ----------
c_info "Giải nén bản macOS..."
mkdir -p "$WORK/mac"
unzip -q "$MAC_ZIP" -d "$WORK/mac"
MAC_APP_BUNDLE="$(find "$WORK/mac" -maxdepth 1 -type d -iname '*.app' | head -n1)"
[[ -n "$MAC_APP_BUNDLE" ]] || die "Không tìm thấy .app trong file macOS."
MAC_APP="$(find "$MAC_APP_BUNDLE" -type d -path '*Resources/app' -not -path '*node_modules*' | head -n1)"
[[ -n "$MAC_APP" && -f "$MAC_APP/main.js" ]] || die "resources/app trong bản macOS không hợp lệ."
VERSION="$(basename "$MAC_ZIP" | grep -oE '[0-9]+-[0-9]+-[0-9]+-[0-9]+' | tr '-' '.' | head -n1)"
[[ -n "$VERSION" ]] || VERSION="unknown"
c_ok "Nội dung macOS: $MAC_APP (phiên bản $VERSION)"

# ---------- 3. Chuẩn bị thư mục cài đích ----------
STAGE="$WORK/stage"
mkdir -p "$STAGE"

if [[ "$ELECTRON_SHELL" == "skip" ]]; then
  c_info "Giữ nguyên vỏ Electron cũ, chỉ port nội dung (giống bản v1)."
  cp -a "$LINUX_ROOT/." "$STAGE/"
else
  # xác định version electron mac dùng, để tải đúng bản chính chủ
  ELECTRON_ZIP=""
  if [[ "$ELECTRON_SHELL" == "auto" ]]; then
    EVER="$(grep -oE '"electron"\s*:\s*"[^"]+"' "$MAC_APP/package.json" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
    [[ -n "$EVER" ]] || die "Không đọc được version electron từ package.json của bản Mac, hãy dùng --electron-shell <đường dẫn file zip electron> thay vì 'auto'."
    c_info "Bản macOS được build với Electron $EVER -> sẽ tải đúng bản chính chủ này cho Linux x64..."
    URL="https://github.com/electron/electron/releases/download/v${EVER}/electron-v${EVER}-linux-x64.zip"
    ELECTRON_ZIP="$WORK/electron-${EVER}-linux-x64.zip"
    command -v curl >/dev/null 2>&1 || die "Cần lệnh 'curl' để tải Electron tự động."
    curl -fL --progress-bar "$URL" -o "$ELECTRON_ZIP" || die "Tải Electron $EVER thất bại. Kiểm tra mạng, hoặc dùng --electron-shell <file.zip> đã tải sẵn."
  elif [[ -f "$ELECTRON_SHELL" ]]; then
    ELECTRON_ZIP="$ELECTRON_SHELL"
  else
    die "--electron-shell phải là 'auto', 'skip', hoặc đường dẫn tới 1 file electron-vX.Y.Z-linux-x64.zip có sẵn."
  fi

  c_info "Giải nén vỏ Electron mới..."
  unzip -q "$ELECTRON_ZIP" -d "$STAGE"
  [[ -f "$STAGE/electron" ]] || die "File zip Electron không đúng định dạng (thiếu file thực thi 'electron')."
  rm -f "$STAGE/resources/default_app.asar"
  mkdir -p "$STAGE/resources/app"
  c_info "Chuyển node_modules gốc (biên dịch cho Linux x64) sang vỏ mới..."
  cp -a "$LINUX_APP/node_modules" "$STAGE/resources/app/node_modules"
  cp "$LINUX_APP/package.json" "$STAGE/resources/app/package.json"
  # đặt lại tên file thực thi cho gọn (không bắt buộc, chỉ cho đẹp)
  mv "$STAGE/electron" "$STAGE/GeoGebra"
  c_ok "Đã dựng vỏ Electron mới thành công."
fi

STAGE_APP="$(find "$STAGE" -type d -path '*resources/app' -not -path '*node_modules*' | head -n1)"
[[ -n "$STAGE_APP" ]] || die "Lỗi nội bộ: không tìm thấy resources/app trong bản dựng."

# ---------- 4. Ghép nội dung macOS vào resources/app ----------
c_info "Ghép html/main.js/preload.js/ggb-config.js từ macOS..."
rm -rf "$STAGE_APP/html"
cp -r "$MAC_APP/html" "$STAGE_APP/html"
cp "$MAC_APP/main.js" "$STAGE_APP/main.js"
cp "$MAC_APP/preload.js" "$STAGE_APP/preload.js"
[[ -f "$MAC_APP/ggb-config.js" ]] && cp "$MAC_APP/ggb-config.js" "$STAGE_APP/ggb-config.js"
[[ -f "$STAGE/version" ]] && echo -n "$VERSION" > "$STAGE/version"

MAIN_BIN="$(find "$STAGE" -maxdepth 1 -type f -perm -u+x ! -name '*.so*' ! -iname '*.pak' | grep -v 'chrome_crashpad_handler\|chrome-sandbox' | head -n1)"
[[ -n "$MAIN_BIN" ]] || die "Không tìm thấy file thực thi chính trong bản dựng."
chmod +x "$MAIN_BIN"
[[ -f "$STAGE/chrome-sandbox" ]] && chmod +x "$STAGE/chrome-sandbox" || true
[[ -f "$STAGE/chrome_crashpad_handler" ]] && chmod +x "$STAGE/chrome_crashpad_handler" || true

# ---------- 5. Cài đặt ----------
if [[ -d "$INSTALL_DIR" ]]; then
  BACKUP_DIR="${INSTALL_DIR}.bak-$(date +%Y%m%d-%H%M%S)"
  c_warn "Sao lưu bản cài hiện tại: $BACKUP_DIR"
  cp -a "$INSTALL_DIR" "$BACKUP_DIR"
fi
mkdir -p "$BIN_DIR" "$DESKTOP_DIR" "$ICON_DIR"
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -a "$STAGE/." "$INSTALL_DIR/"
MAIN_BIN="$INSTALL_DIR/$(basename "$MAIN_BIN")"

# ---------- 6. Xử lý chrome-sandbox (cần setuid root để bật sandbox) ----------
SANDBOX_OK=0
if [[ -f "$INSTALL_DIR/chrome-sandbox" ]]; then
  if sudo -n chown root:root "$INSTALL_DIR/chrome-sandbox" 2>/dev/null && \
     sudo -n chmod 4755 "$INSTALL_DIR/chrome-sandbox" 2>/dev/null; then
    SANDBOX_OK=1
    c_ok "Đã cấp quyền setuid cho chrome-sandbox."
  fi
fi

# ---------- 7. Launcher + icon + .desktop ----------
ENV_LINE=""
# Dùng biến môi trường thay vì cờ --no-sandbox: nếu truyền --no-sandbox làm
# đối số dòng lệnh, main.js của GeoGebra sẽ hiểu nhầm nó là tên file cần mở
# ("Attempt to load file --no-sandbox" -> "Cannot open file"). Biến môi
# trường được Electron xử lý ở tầng lõi, không lọt vào argv của app.
[[ "$SANDBOX_OK" -eq 0 ]] && ENV_LINE='export ELECTRON_DISABLE_SANDBOX=1'
cat > "$BIN_DIR/geogebra" <<EOF
#!/usr/bin/env bash
$ENV_LINE
exec "$MAIN_BIN" "\$@"
EOF
chmod +x "$BIN_DIR/geogebra"

ICON_LINE="Icon=accessories-calculator"
ICNS_SRC="$(find "$MAC_APP_BUNDLE" -maxdepth 3 -iname '*.icns' | head -n1)"
if [[ -n "$ICNS_SRC" ]] && command -v python3 >/dev/null 2>&1 && python3 -c "import PIL" >/dev/null 2>&1; then
  if python3 - "$ICNS_SRC" "$ICON_DIR/geogebra.png" <<'PYEOF'
import sys
from PIL import Image
Image.open(sys.argv[1]).save(sys.argv[2])
PYEOF
  then ICON_LINE="Icon=$ICON_DIR/geogebra.png"; fi
fi

cat > "$DESKTOP_DIR/geogebra.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=GeoGebra Classic 6
Comment=Dynamic mathematics software (ported v$VERSION)
Exec=$BIN_DIR/geogebra %F
Terminal=false
Categories=Education;Science;Math;
$ICON_LINE
EOF
chmod +x "$DESKTOP_DIR/geogebra.desktop"

c_ok "Hoàn tất! Cài tại: $INSTALL_DIR"
echo "  Chạy bằng:  geogebra   (đảm bảo ~/.local/bin có trong PATH)"
if [[ "$SANDBOX_OK" -eq 0 ]]; then
  c_warn "Không cấp được quyền setuid cho chrome-sandbox (cần sudo không hỏi mật khẩu)."
  c_warn "Launcher đã tự đặt ELECTRON_DISABLE_SANDBOX=1 để app vẫn chạy được (ít bảo mật hơn 1 chút)."
  echo "  Muốn bật lại sandbox đầy đủ, chạy 1 lần:"
  echo "    sudo chown root:root \"$INSTALL_DIR/chrome-sandbox\" && sudo chmod 4755 \"$INSTALL_DIR/chrome-sandbox\""
  echo "  rồi xoá dòng 'export ELECTRON_DISABLE_SANDBOX=1' trong $BIN_DIR/geogebra"
fi
