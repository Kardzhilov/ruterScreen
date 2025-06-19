#!/bin/bash
# Improved Firefox launcher that works with both X11 and Wayland (including labwc)

# Ruter URL - Replace this with your URL
RUTER_URL=""

# Weather Location ID - Replace this with weather widget location ID (e.g., "wl8757" for Oslo)
WEATHER_LOCATION_ID="wl8757"

# Display mode - "combined" for timetable+weather, "timetable" for timetable only
DISPLAY_MODE="combined"

# Path to the HTML display files
DISPLAY_HTML_PATH="$(dirname "$(dirname "$(realpath "$0")")")/display.html"
DISPLAY_TIMETABLE_ONLY_PATH="$(dirname "$(dirname "$(realpath "$0")")")/display-timetable-only.html"

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

# Create a customized HTML file with the actual URLs
CUSTOM_HTML_PATH="$TEMP_PROFILE/display.html"
echo "Creating customized display HTML at $CUSTOM_HTML_PATH"

# Check if URLs are set
if [ -z "$RUTER_URL" ]; then
    echo "Warning: RUTER_URL is not set. Please configure it in this script."
    RUTER_URL="https://mon.ruter.no/"
fi

# Determine which template to use based on display mode
if [ "$DISPLAY_MODE" = "timetable" ]; then
    echo "Using timetable-only display mode"
    TEMPLATE_PATH="$DISPLAY_TIMETABLE_ONLY_PATH"
    
    # Copy the timetable-only template and replace placeholders
    if [ -f "$TEMPLATE_PATH" ]; then
        cp "$TEMPLATE_PATH" "$CUSTOM_HTML_PATH"
        
        # Replace URL placeholder
        sed -i "s|RUTER_URL_PLACEHOLDER|$RUTER_URL|g" "$CUSTOM_HTML_PATH"
        
        echo "URLs configured:"
        echo "  Ruter: $RUTER_URL"
        echo "  Display mode: Timetable only"
    else
        echo "Error: Timetable-only HTML template not found at $TEMPLATE_PATH"
        exit 1
    fi
else
    echo "Using combined display mode (timetable + weather)"
    TEMPLATE_PATH="$DISPLAY_HTML_PATH"
    
    if [ -z "$WEATHER_LOCATION_ID" ]; then
        echo "Using default weather location ID (Oslo - wl8757)"
        WEATHER_LOCATION_ID="wl8757"
    fi
    
    # Copy the combined template and replace placeholders
    if [ -f "$TEMPLATE_PATH" ]; then
        cp "$TEMPLATE_PATH" "$CUSTOM_HTML_PATH"
        
        # Generate widget ID - use a more predictable format that works better with weatherwidget.org
        WIDGET_ID="ww_ruterscreen_$(date +%Y%m%d%H%M%S)"
        
        # Replace URL and widget placeholders - need to replace multiple instances
        sed -i "s|RUTER_URL_PLACEHOLDER|$RUTER_URL|g" "$CUSTOM_HTML_PATH"
        sed -i "s|WEATHER_WIDGET_ID_PLACEHOLDER|$WIDGET_ID|g" "$CUSTOM_HTML_PATH"
        sed -i "s|WEATHER_LOCATION_ID_PLACEHOLDER|$WEATHER_LOCATION_ID|g" "$CUSTOM_HTML_PATH"
        
        # Debug: Check if replacements worked
        echo "Debug: Checking widget ID replacements..."
        if grep -q "$WIDGET_ID" "$CUSTOM_HTML_PATH"; then
            echo "  ✓ Widget ID successfully replaced with: $WIDGET_ID"
        else
            echo "  ✗ Widget ID replacement failed!"
        fi
        
        if grep -q "$WEATHER_LOCATION_ID" "$CUSTOM_HTML_PATH"; then
            echo "  ✓ Location ID successfully replaced with: $WEATHER_LOCATION_ID"
        else
            echo "  ✗ Location ID replacement failed!"
        fi
        
        # Test weather widget service connectivity
        echo "Debug: Testing weather widget service connectivity..."
        if curl -s --connect-timeout 5 "https://app3.weatherwidget.org/js/?id=$WIDGET_ID" | head -c 10 > /dev/null; then
            echo "  ✓ Weather widget service is reachable"
        else
            echo "  ⚠ Weather widget service may not be reachable (check internet connection)"
        fi
        
        echo "URLs configured:"
        echo "  Ruter: $RUTER_URL"
        echo "  Weather Location ID: $WEATHER_LOCATION_ID"
        echo "  Weather Widget ID: $WIDGET_ID"
        echo "  Display mode: Combined (timetable + weather)"
    else
        echo "Error: Combined display HTML template not found at $TEMPLATE_PATH"
        exit 1
    fi
fi

# Create a log file for debugging
LOG_FILE="/tmp/firefox_launch.log"
echo "Firefox launch log - $(date)" > "$LOG_FILE"

# Print environment details
echo "Environment variables:" >> "$LOG_FILE"
env | grep -E 'DISPLAY|WAYLAND|XDG|GDK|MOZ' >> "$LOG_FILE"

echo "Opening display with Ruter timetable and weather in fullscreen mode in Firefox..."

# Launch Firefox with appropriate settings
if [ "$USING_WAYLAND" = true ]; then
    echo "Launching Firefox in Wayland mode..."
    # Wayland approach - use different flags
    firefox-esr --profile "$TEMP_PROFILE" --kiosk "file://$CUSTOM_HTML_PATH" >> "$LOG_FILE" 2>&1 &
else
    echo "Launching Firefox in X11 mode..."
    # X11 approach - with no-remote flag
    firefox-esr --profile "$TEMP_PROFILE" --no-remote --kiosk "file://$CUSTOM_HTML_PATH" >> "$LOG_FILE" 2>&1 &
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
CUSTOM_HTML_PATH="$1"
PROFILE="$2"

# Set environment variables that might be needed
[ -z "$DISPLAY" ] && export DISPLAY=:0
export GDK_BACKEND=wayland
export MOZ_ENABLE_WAYLAND=1
export XDG_SESSION_TYPE=wayland
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-"/run/user/$(id -u)"}
export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-0}

# Launch Firefox with all environment variables properly set
/usr/bin/firefox-esr --profile "$PROFILE" --kiosk "file://$CUSTOM_HTML_PATH"
EOF
    
    chmod +x "$TEMP_PROFILE/launch_firefox.sh"
    
    # Try the wrapper script
    "$TEMP_PROFILE/launch_firefox.sh" "$CUSTOM_HTML_PATH" "$TEMP_PROFILE" >> "$LOG_FILE" 2>&1 &
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
