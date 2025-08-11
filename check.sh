echo "===== Date/Time Information ====="
# Show local time in ISO format with timezone
echo "Local time : $(date '+%Y-%m-%d %H:%M:%S %z (%Z)')"
# Show UTC time in ISO format
echo "UTC time   : $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
# Show epoch time (seconds since 1970-01-01)
echo "Epoch time : $(date +%s)"

# Display detailed time settings from systemd
timedatectl

# Check LANG and LC_TIME
locale | grep -E '^(LANG|LC_TIME)='

# Check all important LC_* variables for UK settings
locale | grep -E 'LANG=|LC_ALL=|LC_TIME=|LC_NUMERIC=|LC_MONETARY=|LC_MEASUREMENT=|LC_PAPER='

echo


echo "===== Phiên bản Chrome/Chromium ====="
if command -v google-chrome >/dev/null 2>&1; then
    google-chrome --version
elif command -v google-chrome-stable >/dev/null 2>&1; then
    google-chrome-stable --version
elif command -v chromium >/dev/null 2>&1; then
    chromium --version
elif command -v chromium-browser >/dev/null 2>&1; then
    chromium-browser --version
else
    echo "⚠️ Không tìm thấy Chrome/Chromium."
fi
echo

echo "===== IP hiện tại ====="
echo "IP nội bộ:"
hostname -I
if command -v curl >/dev/null 2>&1; then
    echo "Public IPv4: $(curl -4s https://ifconfig.co)"
    echo "Public IPv6: $(curl -6s https://ifconfig.co)"
else
    echo "⚠️ Thiếu curl để lấy IP công khai."
fi
