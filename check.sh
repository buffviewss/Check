#!/usr/bin/env bash
# sys-check.sh — Inspector for Ubuntu/Lubuntu 24.04
# Author: ChatGPT
# Usage: chmod +x sys-check.sh && ./sys-check.sh

set -uo pipefail

bold()   { printf "\033[1m%s\033[0m\n" "$*"; }
info()   { printf "  • %s\n" "$*"; }
warn()   { printf "\033[33m  ! %s\033[0m\n" "$*"; }
err()    { printf "\033[31m  x %s\033[0m\n" "$*"; }
sep()    { printf "\n"; }
have()   { command -v "$1" >/dev/null 2>&1; }
try_run(){ local d="$1"; shift; "$@" 2>/dev/null || warn "$d: không có dữ liệu"; }

# ---------- 1) Ngày/giờ, múi giờ, locale, vị trí ----------
bold "1) Ngày/giờ & vị trí hiện tại"

# Thời gian (đủ kiểu)
info "Local (đọc dễ): $(date '+%Y-%m-%d %H:%M:%S %z (%Z)')"
info "Local ISO 8601: $(date '+%Y-%m-%dT%H:%M:%S%z')"
info "UTC ISO 8601  : $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
info "Epoch (giây)  : $(date +%s)"

# Múi giờ & NTP
if have timedatectl; then
  info "timedatectl:"
  timedatectl | sed 's/^/    /'
  # Trạng thái đồng bộ NTP (nếu có systemd-timesyncd)
  if timedatectl show-timesync >/dev/null 2>&1; then
    info "timesyncd:"
    timedatectl show-timesync | sed 's/^/    /'
  fi
else
  warn "timedatectl không có; fallback date & /etc/timezone"
  [ -f /etc/timezone ] && info "Timezone file: $(cat /etc/timezone)"
fi

# Liên kết localtime
if [ -L /etc/localtime ]; then
  info "/etc/localtime → $(readlink -f /etc/localtime)"
fi

# Đồng hồ phần cứng
if have hwclock; then
  info "Hardware clock: $(hwclock --show 2>/dev/null || echo 'cần quyền root/không khả dụng')"
fi

# Locale hiển thị giờ
info "Locale hiển thị giờ:"
locale | grep -E '^(LANG|LC_TIME)=' | sed 's/^/    /'

# Vị trí hiện tại (theo IP)
bold "   1a) IP công khai & vị trí"
PUBIP4=""; PUBIP6=""
if have curl; then
  PUBIP4=$(curl -4s https://ifconfig.co 2>/dev/null || true)
  PUBIP6=$(curl -6s https://ifconfig.co 2>/dev/null || true)
  [ -n "$PUBIP4" ] && info "Public IPv4: $PUBIP4"
  [ -n "$PUBIP6" ] && info "Public IPv6: $PUBIP6"

  # Thử ipinfo rồi ipapi
  GEO_JSON="$(curl -s https://ipinfo.io/json 2>/dev/null || true)"
  if [ -z "$GEO_JSON" ] || echo "$GEO_JSON" | grep -q '"error"'; then
    GEO_JSON="$(curl -s https://ipapi.co/json 2>/dev/null || true)"
  fi

  if [ -n "$GEO_JSON" ]; then
    if have jq; then
      CITY=$(echo "$GEO_JSON" | jq -r '.city // empty,.region // empty,.country // empty' | paste -sd ', ' -)
      LOC=$(echo "$GEO_JSON" | jq -r '.loc // (.latitude|tostring+", "+.longitude|tostring) // empty')
      ORG=$(echo "$GEO_JSON" | jq -r '.org // .asn // empty')
    else
      CITY=$(echo "$GEO_JSON" | grep -Eo '"city" *: *"[^"]*"' | head -n1 | sed 's/.*: *"\(.*\)"/\1/')
      REGION=$(echo "$GEO_JSON" | grep -Eo '"region" *: *"[^"]*"' | head -n1 | sed 's/.*: *"\(.*\)"/\1/')
      COUNTRY=$(echo "$GEO_JSON" | grep -Eo '"country" *: *"[^"]*"' | head -n1 | sed 's/.*: *"\(.*\)"/\1/')
      CITY=$(printf "%s" "${CITY}${REGION:+, $REGION}${COUNTRY:+, $COUNTRY}")
      LOC=$(echo "$GEO_JSON" | grep -Eo '"loc" *: *"[^"]*"' | head -n1 | sed 's/.*: *"\(.*\)"/\1/')
      ORG=$(echo "$GEO_JSON" | grep -Eo '"org" *: *"[^"]*"' | head -n1 | sed 's/.*: *"\(.*\)"/\1/')
    fi
    [ -n "$CITY" ] && info "Vị trí (ước lượng): $CITY"
    [ -n "$LOC" ] && info "Toạ độ (ước lượng): $LOC"
    [ -n "$ORG" ] && info "Nhà mạng/ASN: $ORG"
  else
    warn "Không lấy được thông tin vị trí (mạng chặn hoặc thiếu curl)."
  fi
else
  warn "Thiếu curl → không thể dò IP/vị trí công khai."
fi
sep

# ---------- 2) Chrome/Chromium ----------
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

# ---------- 3) Fonts / Đồ hoạ / Audio ----------
bold "3) Thông tin máy (fonts/đồ hoạ/audio)"

bold "   3a) Fonts"
if have fc-match; then
  info "Sans: $(fc-match -f '%{family[0]} (%{file})\n' sans-serif 2>/dev/null)"
  info "Serif: $(fc-match -f '%{family[0]} (%{file})\n' serif 2>/dev/null)"
  info "Monospace: $(fc-match -f '%{family[0]} (%{file})\n' monospace 2>/dev/null)"
  have fc-list && info "Tổng font: $(fc-list : family | wc -l | tr -d ' ')"
else
  warn "fontconfig chưa cài (fc-match). Cài: sudo apt install fontconfig"
fi
if have gsettings; then
  info "GNOME gsettings:"
  try_run "gsettings font-name" gsettings get org.gnome.desktop.interface font-name | sed 's/^/    /'
  try_run "gsettings document-font-name" gsettings get org.gnome.desktop.interface document-font-name | sed 's/^/    /'
  try_run "gsettings monospace-font-name" gsettings get org.gnome.desktop.interface monospace-font-name | sed 's/^/    /'
fi
[ -f "$HOME/.config/lxqt/lxqt.conf" ] && awk -F '=' '/^font=/{print "  • LXQt font: " $2}' "$HOME/.config/lxqt/lxqt.conf"

bold "   3b) Đồ hoạ (GPU/OpenGL/Vulkan)"
info "Session: ${XDG_SESSION_DESKTOP:-unknown} / ${XDG_CURRENT_DESKTOP:-unknown} | Display: ${DISPLAY:-none}"
try_run "lspci VGA" sh -c "lspci | grep -E 'VGA|3D|Display' | sed 's/^/    /'"
if have glxinfo; then info "glxinfo -B:"; glxinfo -B | sed 's/^/    /'; else warn "Cài: sudo apt install mesa-utils"; fi
if have vulkaninfo; then info "vulkaninfo (rút gọn):"; vulkaninfo | sed -n '1,40p' | sed 's/^/    /'; else warn "Cài: sudo apt install vulkan-tools"; fi

bold "   3c) Audio"
if have pactl; then
  info "pactl info:"; pactl info | sed 's/^/    /'
  info "Sinks:"; pactl list short sinks | sed 's/^/    /'
  info "Sources:"; pactl list short sources | sed 's/^/    /'
else
  warn "Thiếu pactl (pulseaudio/pipewire)."
fi
have wpctl && { info "wpctl status:"; wpctl status | sed 's/^/    /'; }
have aplay && { info "ALSA playback (aplay -l):"; aplay -l | sed 's/^/    /'; }
have arecord && { info "ALSA capture (arecord -l):"; arecord -l | sed 's/^/    /'; }
sep

# ---------- 4) NekoBox ----------
bold "4) NekoBox"
NEKO_FOUND=false
for c in nekobox NekoBox nekobox-for-linux nekoray; do
  if have "$c"; then
    info "Lệnh: $c"
    ($c --version || $c -v) 2>/dev/null | head -n1 | sed 's/^/    /'
    NEKO_FOUND=true
  fi
done
if have flatpak && flatpak info io.github.NekoBoxForLinux.NekoBox >/dev/null 2>&1; then
  info "Flatpak NekoBox:"; flatpak info io.github.NekoBoxForLinux.NekoBox | sed -n '1,20p' | sed 's/^/    /'
  NEKO_FOUND=true
fi
if have snap && snap list | grep -iq nekobox; then
  info "Snap NekoBox:"; snap list | grep -i nekobox | sed 's/^/    /'
  NEKO_FOUND=true
fi
ps aux | grep -i '[n]ekobox' >/dev/null 2>&1 && { info "Tiến trình NekoBox:"; ps aux | grep -i '[n]ekobox' | sed 's/^/    /'; NEKO_FOUND=true; }
[ "$NEKO_FOUND" = false ] && warn "Chưa tìm thấy NekoBox (AppImage có thể không hỗ trợ --version)."
sep

# ---------- 5) Mạng/IP + đề xuất ----------
bold "5) Thông tin mạng & IP"

# Tổng quát
info "Hostname: $(hostname)"
info "Uptime: $(uptime -p 2>/dev/null || cut -d',' -f1 /proc/uptime 2>/dev/null)"

# IP nội bộ (IPv4/IPv6)
info "IP nội bộ (IPv4):"
try_run "ip -4 addr" sh -c "ip -o -4 addr show scope global | awk '{print \"    \"$2\": \"$4}'"
info "IP nội bộ (IPv6):"
try_run "ip -6 addr" sh -c "ip -o -6 addr show scope global | awk '{print \"    \"$2\": \"$4}'"

# Gateway mặc định
info "Default route (IPv4):"
try_run "ip route" sh -c "ip route show default | sed 's/^/    /'"
info "Default route (IPv6):"
try_run "ip -6 route" sh -c "ip -6 route show default | sed 's/^/    /'"

# DNS đang dùng
if have resolvectl; then
  info "DNS (resolvectl):"
  resolvectl dns 2>/dev/null | sed 's/^/    /'
  resolvectl status 2>/dev/null | sed -n '1,40p' | sed 's/^/    /'
elif have systemd-resolve; then
  info "DNS (systemd-resolve):"
  systemd-resolve --status 2>/dev/null | sed -n '1,40p' | sed 's/^/    /'
elif [ -f /etc/resolv.conf ]; then
  info "DNS (/etc/resolv.conf):"
  grep -E '^\s*nameserver' /etc/resolv.conf | sed 's/^/    /'
fi

# SSID Wi-Fi (nếu dùng)
if have nmcli; then
  SSID=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '$1=="yes"{print $2; exit}')
  [ -n "$SSID" ] && info "Wi‑Fi SSID: $SSID"
elif have iwgetid; then
  SSID=$(iwgetid -r 2>/dev/null || true)
  [ -n "$SSID" ] && info "Wi‑Fi SSID: $SSID"
fi

# Public IP nhắc lại (đã lấy ở mục 1)
[ -n "${PUBIP4:-}" ] && info "Public IPv4 (nhắc): $PUBIP4"
[ -n "${PUBIP6:-}" ] && info "Public IPv6 (nhắc): $PUBIP6"

# Cổng đang lắng nghe
if have ss; then
  info "Cổng đang lắng nghe (TCP/UDP):"
  ss -tulwn | sed 's/^/    /'
else
  warn "Thiếu ss (iproute2)."
fi

# Kiểm tra kết nối nhanh
if have ping; then
  info "Ping 1.1.1.1 (2 gói):"
  ping -c 2 -W 2 1.1.1.1 2>/dev/null | sed 's/^/    /' || warn "Ping 1.1.1.1 thất bại"
  info "Ping google.com (2 gói):"
  ping -c 2 -W 2 google.com 2>/dev/null | sed 's/^/    /' || warn "Ping google.com thất bại (DNS hoặc mạng)"
fi

bold "Hoàn tất ✅"
