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
err()    { printf "\033[31m  x %s\033[0m\n" "$*"; }
sep()    { printf "\n"; }
have()   { command -v "$1" >/dev/null 2>&1; }
try_run(){ local d="$1"; shift; "$@" 2>/dev/null || warn "$d: không có dữ liệu"; }

# ====== 1) Ngày/giờ, múi giờ, locale, vị trí ======
bold "1) Ngày/giờ & vị trí hiện tại"

# Thời gian
info "Local (đọc dễ): $(date '+%Y-%m-%d %H:%M:%S %z (%Z)')"
info "Local ISO 8601: $(date '+%Y-%m-%dT%H:%M:%S%z')"
info "UTC ISO 8601  : $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
info "Epoch (giây)  : $(date +%s)"

# Múi giờ & NTP
if have timedatectl; then
  info "timedatectl:"
  timedatectl | sed 's/^/    /'
  if timedatectl show-timesync >/dev/null 2>&1; then
    info "timesyncd:"
    timedatectl show-timesync | sed 's/^/    /'
  fi
else
  warn "timedatectl không có; fallback date & /etc/timezone"
  [ -f /etc/timezone ] && info "Timezone file: $(cat /etc/timezone)"
fi

# Liên kết localtime
[ -L /etc/localtime ] && info "/etc/localtime → $(readlink -f /etc/localtime)"

# Đồng hồ phần cứng
have hwclock && info "Hardware clock: $(hwclock --show 2>/dev/null || echo 'cần quyền root/không khả dụng')"

# Locale hiển thị giờ
info "Locale hiển thị giờ:"
locale | grep -E '^(LANG|LC_TIME)=' | sed 's/^/    /'

# Vị trí hiện tại
bold "   1a) IP công khai & vị trí"
PUBIP4=$(curl -4s https://ifconfig.co 2>/dev/null || true)
PUBIP6=$(curl -6s https://ifconfig.co 2>/dev/null || true)
[ -n "$PUBIP4" ] && info "Public IPv4: $PUBIP4"
[ -n "$PUBIP6" ] && info "Public IPv6: $PUBIP6"

GEO_JSON="$(curl -s https://ipinfo.io/json 2>/dev/null || true)"
[ -z "$GEO_JSON" ] && GEO_JSON="$(curl -s https://ipapi.co/json 2>/dev/null || true)"

if [ -n "$GEO_JSON" ]; then
  if have jq; then
    CITY=$(echo "$GEO_JSON" | jq -r '.city // empty,.region // empty,.country // empty' | paste -sd ', ' -)
    LOC=$(echo "$GEO_JSON" | jq -r '.loc // (.latitude|tostring+", "+.longitude|tostring) // empty')
    ORG=$(echo "$GEO_JSON" | jq -r '.org // .asn // empty')
  else
    CITY=$(echo "$GEO_JSON" | grep -Eo '"city" *: *"[^"]*"' | sed 's/.*: *"\(.*\)"/\1/')
    REGION=$(echo "$GEO_JSON" | grep -Eo '"region" *: *"[^"]*"' | sed 's/.*: *"\(.*\)"/\1/')
    COUNTRY=$(echo "$GEO_JSON" | grep -Eo '"country" *: *"[^"]*"' | sed 's/.*: *"\(.*\)"/\1/')
    CITY="${CITY}${REGION:+, $REGION}${COUNTRY:+, $COUNTRY}"
    LOC=$(echo "$GEO_JSON" | grep -Eo '"loc" *: *"[^"]*"' | sed 's/.*: *"\(.*\)"/\1/')
    ORG=$(echo "$GEO_JSON" | grep -Eo '"org" *: *"[^"]*"' | sed 's/.*: *"\(.*\)"/\1/')
  fi
  [ -n "$CITY" ] && info "Vị trí (ước lượng): $CITY"
  [ -n "$LOC" ] && info "Toạ độ: $LOC"
  [ -n "$ORG" ] && info "Nhà mạng/ASN: $ORG"
else
  warn "Không lấy được thông tin vị trí."
fi
sep

# ====== 2) Chrome/Chromium ======
bold "2) Phiên bản Chrome/Chromium"
found_browser=false
check_browser(){ local n="$1"; if have "$n"; then info "$n: $("$n" --version 2>/dev/null | tr -s ' ')"; found_browser=true; fi; }
check_browser google-chrome
check_browser google-chrome-stable
check_browser chrome
check_browser chromium
check_browser chromium-browser
if have flatpak; then
  flatpak info com.google.Chrome >/dev/null 2>&1 && { info "Flatpak Chrome:"; flatpak info com.google.Chrome | sed -n '1,15p' | sed 's/^/    /'; found_browser=true; }
  flatpak info org.chromium.Chromium >/dev/null 2>&1 && { info "Flatpak Chromium:"; flatpak info org.chromium.Chromium | sed -n '1,15p' | sed 's/^/    /'; found_browser=true; }
fi
if have snap; then
  snap list chromium >/dev/null 2>&1 && { info "Snap chromium:"; snap list chromium | sed 's/^/    /'; found_browser=true; }
fi
[ "$found_browser" = false ] && warn "Không tìm thấy Chrome/Chromium."
sep

# ====== 3) Fonts / Đồ hoạ / Audio ======
# (giữ nguyên như bản trước)
# ... (phần này giữ nguyên như ở bản script trước mà mình đã gửi cho bạn)

# ====== 4) NekoBox ======
# (giữ nguyên như bản trước)

# ====== 5) Mạng/IP ======
# (giữ nguyên như bản trước)
