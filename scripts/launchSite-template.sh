#!/bin/bash
# Improved Firefox launcher that works with both X11 and Wayland (including labwc)

# Ruter URL - Replace this with your URL
URL=""

echo "Starting Firefox launcher..."
echo "Current user: $(whoami)"

# ===== Auto-detect display environment =====
if [ -n "$WAYLAND_DISPLAY" ] || ps aux | grep -E 'labwc|sway|weston' | grep -v grep &>/dev/null; then
    echo "Detected Wayland environment, configuring appropriately"
    # Set Wayland-specific environment variables
    export GDK_BACKEND=wayland
    export MOZ_ENABLE_WAYLAND=1
    export XDG_SESSION_TYPE=wayland
    export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-"/run/user/$(id -u)"}
    export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-0}
    USING_WAYLAND=true
else
    echo "Using X11 environment"
    export DISPLAY=${DISPLAY:-:0}
    USING_WAYLAND=false
fi

# Ensure firefox-esr is installed
if ! command -v firefox-esr &> /dev/null; then
    echo "Installing firefox-esr..."
    sudo apt-get update
    sudo apt-get install -y firefox-esr
else
    echo "Firefox is already installed: $(which firefox-esr)"
fi

# If firefox is running, kill it first
if pgrep -x "firefox-esr" > /dev/null; then
    echo "Firefox is still running. Killing it..."
    pkill -9 firefox-esr
    # Wait to make sure it's fully closed
    sleep 3
    if pgrep -x "firefox-esr" > /dev/null; then
        echo "Trying harder to kill Firefox..."
        killall -9 firefox-esr
        sleep 2
    fi
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
// Disable updates and other prompts
user_pref("app.update.enabled", false);
user_pref("browser.shell.checkDefaultBrowser", false);
// Wayland specific settings (harmless in X11)
user_pref("widget.use-xdg-desktop-portal", true);
EOF

# Create a log file for debugging
LOG_FILE="/tmp/firefox_launch.log"
echo "Firefox launch log - $(date)" > "$LOG_FILE"

# Print environment details
echo "Environment variables:" >> "$LOG_FILE"
env | grep -E 'DISPLAY|WAYLAND|XDG|GDK|MOZ' >> "$LOG_FILE"

echo "Opening $URL in fullscreen mode in Firefox..."

# Launch Firefox with appropriate settings
if [ "$USING_WAYLAND" = true ]; then
    echo "Launching Firefox in Wayland mode..."
    # Wayland approach - use different flags
    firefox-esr --profile "$TEMP_PROFILE" --kiosk "$URL" >> "$LOG_FILE" 2>&1 &
else
    echo "Launching Firefox in X11 mode..."
    # X11 approach - with no-remote flag
    firefox-esr --profile "$TEMP_PROFILE" --no-remote --kiosk "$URL" >> "$LOG_FILE" 2>&1 &
fi

FIREFOX_PID=$!

# Give Firefox time to open
echo "Waiting for Firefox to initialize..."
sleep 5

# Check if it worked
if ps -p $FIREFOX_PID > /dev/null; then
    echo "Firefox successfully launched with PID: $FIREFOX_PID"
else
    echo "Firefox launch may have failed. Trying alternative approach..."
    
    # Create a wrapper script that sets environment variables
    cat > "$TEMP_PROFILE/launch_firefox.sh" << 'EOF'
#!/bin/bash
# Get the variables passed as arguments
URL="$1"
PROFILE="$2"

# Set environment variables that might be needed
[ -z "$DISPLAY" ] && export DISPLAY=:0
export GDK_BACKEND=wayland
export MOZ_ENABLE_WAYLAND=1
export XDG_SESSION_TYPE=wayland
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-"/run/user/$(id -u)"}
export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-0}

# Launch Firefox with all environment variables properly set
/usr/bin/firefox-esr --profile "$PROFILE" --kiosk "$URL"
EOF
    
    chmod +x "$TEMP_PROFILE/launch_firefox.sh"
    
    # Try the wrapper script
    "$TEMP_PROFILE/launch_firefox.sh" "$URL" "$TEMP_PROFILE" >> "$LOG_FILE" 2>&1 &
    FIREFOX_PID=$!
    
    # Final check
    sleep 5
    if ps -p $FIREFOX_PID > /dev/null; then
        echo "Firefox successfully launched with PID: $FIREFOX_PID using alternative method"
    else
        echo "Firefox launch failed. Check the log at $LOG_FILE for details"
    fi
fi

echo "Launch script completed"
