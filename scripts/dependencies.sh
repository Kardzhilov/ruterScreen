#!/bin/bash

# Install dependencies for the project
echo "Installing dependencies..."

# Update package lists if needed (only once a day to avoid unnecessary updates)
LAST_UPDATE=$(stat -c %Y /var/lib/apt/lists/* 2>/dev/null | sort -n | tail -n 1)
NOW=$(date +%s)
ONE_DAY=$((24*60*60))

if [ -z "$LAST_UPDATE" ] || [ $((NOW - LAST_UPDATE)) -gt $ONE_DAY ]; then
    echo "Updating package lists..."
    sudo apt-get update
else
    echo "Package lists are up-to-date, skipping update."
fi

# Install required packages if not already installed
PACKAGES="firefox-esr libva1 libva-drm2 libva-x11-2 vainfo xserver-xorg-video-fbdev xdotool python3-rpi.gpio"
MISSING_PACKAGES=""

for pkg in $PACKAGES; do
    if ! dpkg -l | grep -q "^ii  $pkg "; then
        MISSING_PACKAGES="$MISSING_PACKAGES $pkg"
    fi
done

if [ ! -z "$MISSING_PACKAGES" ]; then
    echo "Installing missing packages: $MISSING_PACKAGES"
    sudo apt-get install -y $MISSING_PACKAGES
else
    echo "All required packages are already installed."
fi

# Install DSI Screen tools if not already installed
BRIGHTNESS_DIR="$HOME/Brightness"
BRIGHTNESS_CHECK="/usr/local/bin/brightness"

if [ -f "$BRIGHTNESS_CHECK" ]; then
    echo "DSI Screen tools already installed, skipping."
else
    echo "Installing DSI Screen tools..."
    ## From https://www.waveshare.com/wiki/7inch_DSI_LCD
    cd "$HOME"
    
    # Expected SHA256 checksum for Brightness.zip (should be updated with actual value)
    # TODO: Verify this checksum matches the legitimate file from Waveshare
    EXPECTED_CHECKSUM="PLACEHOLDER_UPDATE_WITH_ACTUAL_CHECKSUM"
    BRIGHTNESS_URL="https://files.waveshare.com/upload/f/f4/Brightness.zip"
    
    # Download the file
    echo "Downloading DSI Screen tools..."
    if ! wget -O Brightness.zip "$BRIGHTNESS_URL"; then
        echo "Error: Failed to download Brightness.zip"
        cd "$HOME"
        exit 1
    fi
    
    # Verify checksum if not placeholder
    if [ "$EXPECTED_CHECKSUM" != "PLACEHOLDER_UPDATE_WITH_ACTUAL_CHECKSUM" ]; then
        echo "Verifying file integrity..."
        ACTUAL_CHECKSUM=$(sha256sum Brightness.zip | awk '{print $1}')
        if [ "$ACTUAL_CHECKSUM" != "$EXPECTED_CHECKSUM" ]; then
            echo "Error: Checksum verification failed!"
            echo "Expected: $EXPECTED_CHECKSUM"
            echo "Actual: $ACTUAL_CHECKSUM"
            rm -f Brightness.zip
            cd "$HOME"
            exit 1
        fi
        echo "Checksum verified successfully."
    else
        echo "Warning: Checksum verification skipped (placeholder checksum)."
        echo "Current file SHA256: $(sha256sum Brightness.zip | awk '{print $1}')"
    fi
    
    unzip Brightness.zip
    rm Brightness.zip
    cd Brightness
    sudo chmod +x install.sh
    ./install.sh
    cd "$HOME"
    echo "DSI Screen tools installation complete."
fi

echo "All dependencies setup complete."

