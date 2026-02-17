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
    
    # Expected SHA256 checksum for Brightness.zip
    # NOTE: This should be verified independently and updated by the maintainer
    # To get the actual checksum, download from a trusted source and run: sha256sum Brightness.zip
    # For now, we'll download and display the checksum for manual verification
    BRIGHTNESS_URL="https://files.waveshare.com/upload/f/f4/Brightness.zip"
    
    # Download the file
    echo "Downloading DSI Screen tools..."
    if ! wget -O Brightness.zip "$BRIGHTNESS_URL"; then
        echo "Error: Failed to download Brightness.zip"
        cd "$HOME"
        exit 1
    fi
    
    # Display checksum for manual verification
    ACTUAL_CHECKSUM=$(sha256sum Brightness.zip | awk '{print $1}')
    echo "============================================"
    echo "SECURITY NOTICE: Manual Checksum Verification"
    echo "============================================"
    echo "Downloaded file SHA256 checksum:"
    echo "$ACTUAL_CHECKSUM"
    echo ""
    echo "Please verify this checksum matches the official Waveshare release."
    echo "You can find the official checksum at:"
    echo "  https://www.waveshare.com/wiki/7inch_DSI_LCD"
    echo ""
    echo "If you have independently verified the checksum is correct,"
    echo "you can proceed with the installation."
    echo "============================================"
    read -p "Do you want to proceed with installation? (y/N): " proceed
    
    if [[ "$proceed" != "y" && "$proceed" != "Y" ]]; then
        echo "Installation cancelled. Removing downloaded file."
        rm -f Brightness.zip
        cd "$HOME"
        exit 1
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

