#!/bin/bash

# Ruter URL
URL=""

# Ensure firefox-esr is installed
if ! command -v firefox-esr &> /dev/null; then
    echo "Installing firefox-esr..."
    sudo apt-get update
    sudo apt-get install -y firefox-esr
fi

# Set display environment variable
export DISPLAY=:0

# If firefox is running, kill it first
if pgrep -x "firefox-esr" > /dev/null; then
    echo "Firefox is still running. Killing it..."
    pkill firefox-esr
    # Wait to make sure it's fully closed
    sleep 2
fi

# Create a temporary profile to prevent session restore prompts
TEMP_PROFILE=$(mktemp -d)
echo "Creating temporary Firefox profile at $TEMP_PROFILE"

# Create a user.js file in the temporary profile to disable session restore
cat > "$TEMP_PROFILE/user.js" << EOF
// Disable session restore
user_pref("browser.sessionstore.resume_from_crash", false);
user_pref("browser.sessionstore.max_resumed_crashes", -1);
user_pref("browser.sessionstore.enabled", false);
user_pref("browser.sessionstore.resume_session_once", false);
user_pref("browser.startup.page", 0);
EOF

echo "Opening $URL in fullscreen mode in Firefox with a clean profile."
firefox-esr --profile "$TEMP_PROFILE" --no-remote --kiosk "$URL" &

# Give Firefox time to open
sleep 5s
