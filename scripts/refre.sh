#!/bin/bash

# Send F5 key to Firefox to refresh the current page
# Using xdotool to simulate keyboard input

# Set display environment variable
export DISPLAY=:0

# Check if Firefox is running
if pgrep -x "firefox-esr" > /dev/null; then
    echo "$(date): Firefox is running. Refreshing the current page."
    # Focus on Firefox window
    windowid=$(xdotool search --class "firefox" | head -1)
    if [ -n "$windowid" ]; then
        xdotool windowactivate --sync $windowid
        # Send F5 key to refresh
        xdotool key F5
        echo "$(date): Page refreshed successfully."
    else
        echo "$(date): Could not find Firefox window."
    fi
else
    echo "$(date): Firefox is not running."
fi