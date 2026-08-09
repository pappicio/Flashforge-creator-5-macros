#!/bin/sh

# ==============================================================================
# Flashforge Moonraker-Timelapse Automated Setup Script
# ==============================================================================

echo "=== Starting Moonraker Timelapse Setup ==="

# 1. Check Prerequisites (opkg & ffmpeg)
echo "[1/5] Checking prerequisites..."
if ! command -v opkg >/dev/null 2>&1; then
    echo "ERROR: 'opkg' not found. Please install Entware on your system first."
    exit 1
fi

if ! which ffmpeg >/dev/null 2>&1; then
    echo "ffmpeg not found in PATH. Installing via opkg..."
    opkg update && opkg install ffmpeg
    
    # Re-check after installation attempt
    if ! which ffmpeg >/dev/null 2>&1; then
        echo "ERROR: Failed to install ffmpeg via opkg. Please check your network or Entware configuration."
        exit 1
    fi
fi

FFMPEG_PATH=$(which ffmpeg)
echo "ffmpeg verified at: $FFMPEG_PATH"

# 2. Clone Repository
echo "[2/5] Fetching moonraker-timelapse repo..."
cd /usr/data
if [ -d "moonraker-timelapse" ]; then
    echo "Directory already exists, pulling latest updates..."
    cd moonraker-timelapse && git pull
else
    git clone https://github.com/mainsail-crew/moonraker-timelapse.git
fi

# 3. Create Symlinks & Directories
echo "[3/5] Creating symlinks and output directories..."
ln -sf /usr/data/moonraker-timelapse/component/timelapse.py /usr/prog/moonraker/moonraker/moonraker/components/timelapse.py
ln -sf /usr/data/moonraker-timelapse/klipper_macro/timelapse.cfg /usr/data/config/timelapse.cfg
mkdir -p /tmp/timelapse
mkdir -p /usr/data/firmwareRes/camera/video/

# 4. Inject Configurations
echo "[4/5] Updating configuration files..."

# Add include to printer.cfg if missing
if ! grep -q "\[include timelapse.cfg\]" /usr/data/config/printer.cfg; then
    echo -e "\n[include timelapse.cfg]" >> /usr/data/config/printer.cfg
    echo "Added [include timelapse.cfg] to printer.cfg"
fi

# Add [timelapse] block to moonraker.conf if missing
if ! grep -q "\[timelapse\]" /usr/data/config/moonraker.conf; then
    cat << EOF >> /usr/data/config/moonraker.conf

[timelapse]
frame_path: /tmp/timelapse/
output_path: /usr/data/firmwareRes/camera/video/
ffmpeg_binary_path: $FFMPEG_PATH
EOF
    echo "Added [timelapse] section to moonraker.conf"
else
    # Update existing keys if present
    sed -i 's|output_path:.*|output_path: /usr/data/firmwareRes/camera/video/|g' /usr/data/config/moonraker.conf
    sed -i 's|output_path =.*|output_path = /usr/data/firmwareRes/camera/video/|g' /usr/data/config/moonraker.conf
    sed -i "s|ffmpeg_binary_path:.*|ffmpeg_binary_path: $FFMPEG_PATH|g" /usr/data/config/moonraker.conf
    sed -i "s|ffmpeg_binary_path =.*|ffmpeg_binary_path = $FFMPEG_PATH|g" /usr/data/config/moonraker.conf
    echo "Updated output_path and ffmpeg_binary_path in moonraker.conf"
fi

# 5. Completion Message
echo "=== Setup Complete! ==="
echo "Please reboot your printer now."