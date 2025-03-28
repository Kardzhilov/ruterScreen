#!/bin/bash

# Install dependencies for the project
echo "Installing dependencies... this may take a while"
sudo apt-get update && sudo apt-get upgrade -y 
sudo apt-get install -y firefox-esr libva1 libva-drm2 libva-x11-2 vainfo xserver-xorg-video-fbdev libva-drm2 libva-x11-2 vainfo xdotool python3-rpi.gpio

echo "Installing DSI Screen tools"
## From https://www.waveshare.com/wiki/7inch_DSI_LCD
cd $home
wget https://files.waveshare.com/upload/f/f4/Brightness.zip
unzip Brightness.zip
rm Brightness.zip
cd Brightness
sudo chmod +x install.sh
./install.sh
cd $home

