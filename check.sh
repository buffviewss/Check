#!/usr/bin/env bash
# sys-check.sh — Inspector for Ubuntu/Lubuntu 24.04
# Author: ChatGPT
# Usage: chmod +x sys-check.sh && ./sys-check.sh

set -uo pipefail

# ====== 0) Kiểm tra & cài gói thiếu ======
NEEDED_PKGS=(
  curl fontconfig mesa-utils vulkan-tools iproute2 net-tools jq
  pulseaudio-utils pipewire-audio network-manager iw
)

MISSING_PKGS=()
for pkg in "${NEEDED_PKGS[@]}"; do
  dpkg -s "$pkg" >/dev/null 2>&1 || MISSING_PKGS+=("$pkg")
done

if [ "${#MISSING_PKGS[@]}" -gt 0 ]; then
  echo -e "\033[33m[!] Thiếu gói:\033[0m ${MISSING_PKGS[*]}"
  read -rp "Bạn có muốn cài ngay bây giờ? [Y/n]: " ans
  ans=${ans:-Y}
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    sudo apt update
    sudo apt install -y "${MISSING_PKGS[@]}"
  else
    echo -e "\033[33m[!] Tiếp tục chạy nhưng một số chức năng có thể thiếu.\033[0m"
  fi
fi

# ====== Các hàm in ấn ======
bold()   { printf "\033[1m%s\033[0m\n" "$*"; }
info()   { printf "  • %s\n" "$*"; }
warn()   { printf "\033[33m  ! %s\033[0m\n" "$*"; }
sep()    { printf "\n"; }
have()   { command -v "$1" >/dev/null 2>&1; }
try_run(){ local d="$1"; shift; "$@" 2>/dev/null || warn "$d: không có dữ liệu"; }

# Trạng thái kết quả
STATUS_1="✅"; STATUS_2="✅"; STATUS_3="✅"; STATUS_4="✅"; STATUS_5="✅"

# ====== 1) Ngày/giờ, múi giờ, locale, vị trí ======
bold "1) Ngày/giờ & vị trí hiện tại"
info "Local (đọc dễ): $(date '+%Y-%m-%d %H:%M:%S %z (%Z)')"
info "Local ISO 8601: $(date '+%Y-%m-%dT%H:%M:%S%z')"
info "UTC ISO 8601  : $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
info "Epoch (giây)  : $(date +%s)"

if have timedatectl; then
  info "timedatectl:"; timedatectl | sed 's/^/    /'
else
  warn "timedatectl không có"; STATUS_1="⚠️"
fi

[ -L /etc/localtime ] && info "/etc/localtime → $(readlink -f /etc/localtime)"
have hwclock && info "Hardware clock: $(hwclock --show 2>/dev/null || echo 'không khả dụng')"

info "Locale hiển thị giờ:"; locale | grep -E '^(LANG|LC_TIME)=' | sed 's/^/    /'

bold "   1a) IP công khai & vị trí"
PUBIP4=$(curl -4s https://ifconfig.co 2>/dev/null || true)
PUBIP6=$(curl -6s https://ifconfig.co 2>/dev/null || true)
[ -n "$PUBIP4" ] && info "Public IPv4: $PUBIP4" || STATUS_1="⚠️"
[ -n "$PUBIP6" ] && info "Public IPv6: $PUBIP6"

GEO_JSON="$(curl -s https://ipinfo.io/json 2>/dev/null || true)"
[ -z "$GEO_JSON" ] && GEO_JSON="$(curl -s https://ipapi.co/json 2>/dev/null || true)"
if [ -n "$GEO_JSON" ]; then
  if have jq; then
    CITY=$(echo "$GEO_JSON" | jq -r '.city // empty,.region // empty,.country // empty' | paste -sd ', ' -)
    LOC=$(echo "$GEO_JSON" | jq -r '.loc // empty')
    ORG=$(echo "$GEO_JSON" | jq -r '.org // empty')
  fi
  [ -n "$CITY" ] && info "Vị trí (ước lượng): $CITY"
  [ -n "$LOC" ] && info "Toạ độ: $LOC"
  [ -n "$ORG" ] && info "Nhà mạng/ASN: $ORG"
else
  warn "Không lấy được thông tin vị trí."; STATUS_1="⚠️"
fi
sep

# ====== 2) Chrome/Chromium ======
bold "2) Phiên bản Chrome/Chromium"
found_browser=false
check_browser(){ local n="$1"; if have "$n"; then info "$n: $("$n" --version 2>/dev/null)"; found_browser=true; fi; }
check_browser google-chrome
check_browser google-chrome-stable
check_browser chrome
check_browser chromium
check_browser chromium-browser
[ "$found_browser" = false ] && { warn "Không tìm thấy Chrome/Chromium."; STATUS_2="⚠️"; }
sep

# ====== 3) Fonts / Đồ hoạ / Audio ======
bold "3) Thông tin máy (fonts/đồ hoạ/audio)"
have fc-match || { warn "fontconfig chưa cài"; STATUS_3="⚠️"; }
have glxinfo || { warn "mesa-utils chưa cài"; STATUS_3="⚠️"; }
have pactl || { warn "pactl chưa cài"; STATUS_3="⚠️"; }
sep

# ====== 4) NekoBox ======
bold "4) NekoBox"
NEKO_FOUND=false
for c in nekobox NekoBox nekobox-for-linux nekoray; do
  have "$c" && { info "Lệnh: $c"; ($c --version || $c -v) 2>/dev/null; NEKO_FOUND=true; }
done
[ "$NEKO_FOUND" = false ] && { warn "Chưa tìm thấy NekoBox."; STATUS_4="⚠️"; }
sep

# ====== 5) Mạng/IP ======
bold "5) Thông tin mạng & IP"
have ip || { warn "iproute2 chưa cài"; STATUS_5="⚠️"; }
[ -n "${PUBIP4:-}" ] || STATUS_5="⚠️"
sep

# ====== TÓM TẮT CUỐI ======
echo -e "\n\033[1m================= TÓM TẮT KIỂM TRA =================\033[0m"
printf "1) Ngày/giờ & vị trí hiện tại     %s\n" "$STATUS_1"
printf "2) Phiên bản Chrome/Chromium     %s\n" "$STATUS_2"
printf "3) Fonts/Đồ hoạ/Audio            %s\n" "$STATUS_3"
printf "4) NekoBox                       %s\n" "$STATUS_4"
printf "5) Mạng/IP                       %s\n" "$STATUS_5"
echo -e "\033[1m=====================================================\033[0m\n"
