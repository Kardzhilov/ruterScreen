#!/bin/bash

# Source the colors file
source ./scripts/colours.sh

# Safe function to replace a key-value pair in a file
# Usage: safe_replace_config "KEY" "value" "filepath"
safe_replace_config() {
    local key="$1"
    local value="$2"
    local filepath="$3"
    
    # Use a more robust approach: create temp file and replace atomically
    local temp_file=$(mktemp)
    if awk -v key="$key" -v value="$value" '
        BEGIN { found=0 }
        /^[[:space:]]*'"$key"'[[:space:]]*=/ { 
            print key "=\"" value "\""
            found=1
            next
        }
        { print }
        END { if (!found) print key "=\"" value "\"" }
    ' "$filepath" > "$temp_file"; then
        mv "$temp_file" "$filepath"
    else
        rm -f "$temp_file"
        return 1
    fi
}

# Validate weather location ID format
# Usage: validate_weather_location_id "wl1234"
validate_weather_location_id() {
    local location_id="$1"
    
    # Weather widget location IDs should match pattern: wl followed by digits
    if [[ "$location_id" =~ ^wl[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Validate URL format
# Usage: validate_url "https://example.com"
validate_url() {
    local url="$1"
    
    # Basic URL validation - must start with http:// or https://
    if [[ "$url" =~ ^https?:// ]]; then
        return 0
    else
        return 1
    fi
}

echo "${CYAN}Starting setup...${NC}"

# Run dependencies.sh script
./scripts/dependencies.sh 

# Set up screen orientation
echo "${CYAN}Setting up screen orientation...${NC}"
sudo ./scripts/screenOrentation.sh

# Variable to track motion detection status for cronJobs
MOTION_STATUS=""

# Check if launchSite.sh exists; if not, copy from template
if [ ! -f ./scripts/launchSite.sh ]; then
    echo "${YELLOW}Copying launchSite-template.sh to launchSite.sh...${NC}"
    cp ./scripts/launchSite-template.sh ./scripts/launchSite.sh
else
    echo "${GREEN}launchSite.sh already exists.${NC}"
fi

# Configure display mode
echo "${CYAN}Configure your display mode:${NC}"
echo "${YELLOW}1. Timetable only${NC} - Full screen Ruter timetable"
echo "${YELLOW}2. Combined display${NC} - Weather forecast (top) + Ruter timetable (bottom)"
echo ""

current_display_mode=$(grep '^DISPLAY_MODE=' ./scripts/launchSite.sh | cut -d '"' -f 2)
if [ -n "$current_display_mode" ]; then
    if [ "$current_display_mode" = "timetable" ]; then
        echo "${GREEN}Current mode: Timetable only${NC}"
    else
        echo "${GREEN}Current mode: Combined display${NC}"
    fi
    read -p "${MAGENTA}Do you want to change the display mode? (y/N): ${NC}" change_mode
    if [[ "$change_mode" != "y" && "$change_mode" != "Y" ]]; then
        echo "${GREEN}Keeping current display mode.${NC}"
        SKIP_DISPLAY_CONFIG=true
    fi
fi

if [ "$SKIP_DISPLAY_CONFIG" != "true" ]; then
    while true; do
        read -p "${MAGENTA}Select display mode (1 or 2): ${NC}" mode_choice
        case $mode_choice in
            1)
                display_mode="timetable"
                echo "${GREEN}Selected: Timetable only${NC}"
                break
                ;;
            2)
                display_mode="combined"
                echo "${GREEN}Selected: Combined display (weather + timetable)${NC}"
                break
                ;;
            *)
                echo "${RED}Invalid choice. Please select 1 or 2.${NC}"
                ;;
        esac
    done
    
    # Update display mode in launchSite.sh
    safe_replace_config "DISPLAY_MODE" "$display_mode" ./scripts/launchSite.sh
else
    display_mode="$current_display_mode"
fi

# Extract the current URLs from launchSite.sh
current_ruter_url=$(grep '^RUTER_URL=' ./scripts/launchSite.sh | cut -d '"' -f 2)
current_weather_location_id=$(grep '^WEATHER_LOCATION_ID=' ./scripts/launchSite.sh | cut -d '"' -f 2)

if [ -n "$current_ruter_url" ]; then
    read -p "${MAGENTA}The current Ruter URL is set to '$current_ruter_url'. Do you want to update it? (y/N): ${NC}" update_ruter
    if [[ "$update_ruter" == "y" || "$update_ruter" == "Y" ]]; then
        echo "${CYAN}Time to set the Ruter URL for your custom stop.${NC}"
        echo "${CYAN}Go to https://mon.ruter.no/ and fill out/customize your stop.${NC}"
        echo "${CYAN}Once you have set up your custom stop, copy and paste the whole URL into this terminal.${NC}"
        read -p "${MAGENTA}Ruter URL: ${NC}" ruter_url
        
        # Validate URL
        if ! validate_url "$ruter_url"; then
            echo "${RED}Error: Invalid URL format. URL must start with http:// or https://${NC}"
            echo "${YELLOW}Keeping current URL.${NC}"
        else
            # Replace the placeholder URL in launchSite.sh
            safe_replace_config "RUTER_URL" "$ruter_url" ./scripts/launchSite.sh
        fi
    else
        echo "${GREEN}Keeping current Ruter URL.${NC}"
    fi
else
    echo "${YELLOW}No Ruter URL found in launchSite.sh. Setting a new URL.${NC}"
    echo "${CYAN}Time to set the Ruter URL for your custom stop.${NC}"
    echo "${CYAN}Go to https://mon.ruter.no/ and fill out/customize your stop.${NC}"
    echo "${CYAN}Once you have set up your custom stop, copy and paste the whole URL into this terminal.${NC}"
    read -p "${MAGENTA}Ruter URL: ${NC}" ruter_url
    
    # Validate URL
    if ! validate_url "$ruter_url"; then
        echo "${RED}Error: Invalid URL format. URL must start with http:// or https://${NC}"
        echo "${YELLOW}Using default URL: https://mon.ruter.no/${NC}"
        ruter_url="https://mon.ruter.no/"
    fi

    # Replace the placeholder URL in launchSite.sh
    safe_replace_config "RUTER_URL" "$ruter_url" ./scripts/launchSite.sh
fi

# Configure weather location ID only if combined mode is selected
if [ "$display_mode" = "combined" ]; then
    if [ -n "$current_weather_location_id" ]; then
        read -p "${MAGENTA}The current weather location ID is set to '$current_weather_location_id'. Do you want to update it? (y/N): ${NC}" update_weather
        if [[ "$update_weather" == "y" || "$update_weather" == "Y" ]]; then
            echo "${CYAN}Configure your weather location ID for weatherwidget.org.${NC}"
            echo "${CYAN}Weather widget location options:${NC}"
            echo "${CYAN}  1. Oslo, Norway (wl8757)${NC}"
            echo "${CYAN}  2. Custom location ID${NC}"
            echo ""
            echo "${CYAN}To find your custom location ID:${NC}"
            echo "${CYAN}  - Go to https://weatherwidget.org/${NC}"
            echo "${CYAN}  - Search for your city${NC}"
            echo "${CYAN}  - Copy the location ID (e.g., 'wl1234') from the widget code${NC}"
            echo ""
            
            while true; do
                read -p "${MAGENTA}Select option (1 for Oslo, 2 for custom): ${NC}" weather_choice
                case $weather_choice in
                    1)
                        weather_location_id="wl8757"
                        echo "${GREEN}Selected: Oslo, Norway (wl8757)${NC}"
                        break
                        ;;
                    2)
                        read -p "${MAGENTA}Enter your weatherwidget.org location ID (e.g., wl1234): ${NC}" weather_location_id
                        # Validate format
                        if [[ -n "$weather_location_id" ]] && validate_weather_location_id "$weather_location_id"; then
                            echo "${GREEN}Selected: Custom location ($weather_location_id)${NC}"
                            break
                        elif [[ -n "$weather_location_id" ]]; then
                            echo "${RED}Invalid format. Location ID should be 'wl' followed by numbers (e.g., wl8757). Please try again.${NC}"
                        else
                            echo "${RED}Location ID cannot be empty. Please try again.${NC}"
                        fi
                        ;;
                    *)
                        echo "${RED}Invalid choice. Please select 1 or 2.${NC}"
                        ;;
                esac
            done

            # Replace the weather location ID in launchSite.sh
            safe_replace_config "WEATHER_LOCATION_ID" "$weather_location_id" ./scripts/launchSite.sh
        else
            echo "${GREEN}Keeping current weather location ID.${NC}"
        fi
    else
        echo "${YELLOW}No weather location ID found in launchSite.sh. Setting weather location.${NC}"
        echo "${CYAN}Configure your weather location ID for weatherwidget.org.${NC}"
        echo "${CYAN}Weather widget location options:${NC}"
        echo "${CYAN}  1. Oslo, Norway (wl8757)${NC}"
        echo "${CYAN}  2. Custom location ID${NC}"
        echo ""
        echo "${CYAN}To find your custom location ID:${NC}"
        echo "${CYAN}  - Go to https://weatherwidget.org/${NC}"
        echo "${CYAN}  - Search for your city${NC}"
        echo "${CYAN}  - Copy the location ID (e.g., 'wl1234') from the widget code${NC}"
        echo ""
        
        while true; do
            read -p "${MAGENTA}Select option (1 for Oslo, 2 for custom): ${NC}" weather_choice
            case $weather_choice in
                1)
                    weather_location_id="wl8757"
                    echo "${GREEN}Selected: Oslo, Norway (wl8757)${NC}"
                    break
                    ;;
                2)
                    read -p "${MAGENTA}Enter your weatherwidget.org location ID (e.g., wl1234): ${NC}" weather_location_id
                    # Validate format
                    if [[ -n "$weather_location_id" ]] && validate_weather_location_id "$weather_location_id"; then
                        echo "${GREEN}Selected: Custom location ($weather_location_id)${NC}"
                        break
                    elif [[ -n "$weather_location_id" ]]; then
                        echo "${RED}Invalid format. Location ID should be 'wl' followed by numbers (e.g., wl8757). Please try again.${NC}"
                    else
                        echo "${RED}Location ID cannot be empty. Please try again.${NC}"
                    fi
                    ;;
                *)
                    echo "${RED}Invalid choice. Please select 1 or 2.${NC}"
                    ;;
            esac
        done

        # Replace the weather location ID in launchSite.sh
        safe_replace_config "WEATHER_LOCATION_ID" "$weather_location_id" ./scripts/launchSite.sh
    fi
else
    echo "${YELLOW}Timetable-only mode selected. Skipping weather location configuration.${NC}"
fi

# Set up motion detection script
setup_motion_brightness() {
    # Copy the template if not exists
    if [ ! -f ./scripts/motion_brightness.py ]; then
        echo "${YELLOW}Copying motion_brightness_template.py to motion_brightness.py...${NC}"
        cp ./scripts/motion_brightness_template.py ./scripts/motion_brightness.py
        chmod +x ./scripts/motion_brightness.py
    fi

    # First, check if the PIR sensor test utility should be run
    read -p "${MAGENTA}Do you want to test if your PIR motion sensor is working? (y/N): ${NC}" run_test
    if [[ "$run_test" == "y" || "$run_test" == "Y" ]]; then
        echo "${CYAN}Running PIR sensor test...${NC}"
        echo "${YELLOW}This will help verify your sensor is connected to the correct GPIO pin.${NC}"
        sudo python3 ./scripts/pir_test.py
        
        # After the test, ask if they want to continue with motion detection setup
        read -p "${MAGENTA}Continue with motion detection setup? (Y/n): ${NC}" continue_setup
        if [[ "$continue_setup" == "n" || "$continue_setup" == "N" ]]; then
            echo "${YELLOW}Motion detection setup skipped.${NC}"
            MOTION_STATUS="disable_motion"
            return
        fi
    fi
    
    # Read existing values if present
    if [ -f ./scripts/motion_brightness.py ]; then
        # Extract the values with more precise patterns
        current_timeout=$(grep -oP '\-\-timeout.*default=\K[0-9]+' ./scripts/motion_brightness.py)
        current_on_value=$(grep -oP '\-\-on-value.*default="\K[0-9]+' ./scripts/motion_brightness.py)
        current_off_value=$(grep -oP '\-\-off-value.*default="\K[0-9]+' ./scripts/motion_brightness.py)
    else
        # If copying from template, extract from template instead
        current_timeout=$(grep -oP '\-\-timeout.*default=\K[0-9]+' ./scripts/motion_brightness_template.py)
        current_on_value=$(grep -oP '\-\-on-value.*default="\K[0-9]+' ./scripts/motion_brightness_template.py)
        current_off_value=$(grep -oP '\-\-off-value.*default="\K[0-9]+' ./scripts/motion_brightness_template.py)
    fi
    
    # Fallback to hardcoded defaults if extraction fails
    current_timeout=${current_timeout:-30}
    current_on_value=${current_on_value:-255}
    current_off_value=${current_off_value:-0}
    
    # Ask if user wants to enable motion detection
    read -p "${MAGENTA}Do you want to enable motion detection to dim the screen when idle? (Y/n): ${NC}" enable_motion
    if [[ "$enable_motion" == "n" || "$enable_motion" == "N" ]]; then
        echo "${YELLOW}Motion detection will be disabled. Screen will stay at constant brightness.${NC}"
        use_motion=false
        # Set both on and off values to the same (only need to configure one brightness level)
        read -p "${MAGENTA}Do you want to set the screen brightness? (Y/n): ${NC}" set_brightness
        if [[ "$set_brightness" == "n" || "$set_brightness" == "N" ]]; then
            # User doesn't want to change brightness
            echo "${GREEN}Using current brightness settings.${NC}"
            # Set global variable to disable motion
            MOTION_STATUS="disable_motion"
            return
        fi
    else
        use_motion=true
        # Configure timeout for motion detection
        echo "${CYAN}Configure how long before the screen dims when no motion is detected.${NC}"
        read -p "${MAGENTA}Enter timeout in seconds (default is $current_timeout, 30 = 30 seconds): ${NC}" timeout
        # Use default if empty
        timeout=${timeout:-$current_timeout}
        
        # Validate timeout is a positive integer
        if ! [[ "$timeout" =~ ^[0-9]+$ ]] || [ "$timeout" -lt 1 ]; then
            echo "${RED}Invalid timeout. Using default: $current_timeout${NC}"
            timeout=$current_timeout
        fi
        
        # Update the timeout in the file using a safer approach
        if [ -f ./scripts/motion_brightness.py ]; then
            # Use Python to safely update the file
            if python3 -c "
import re
import sys
with open('./scripts/motion_brightness.py', 'r') as f:
    content = f.read()
new_content = re.sub(r\"--timeout',\s*type=int,\s*default=[0-9]+\", 
                     \"--timeout', type=int, default=$timeout\", content)
if content == new_content:
    print('Warning: Pattern not found, timeout value may not have been updated', file=sys.stderr)
    sys.exit(1)
with open('./scripts/motion_brightness.py', 'w') as f:
    f.write(new_content)
"; then
                echo "${GREEN}Timeout set to $timeout seconds.${NC}"
            else
                echo "${RED}Warning: Could not update timeout value in motion_brightness.py${NC}"
            fi
        fi
    fi
    
    # Configure brightness when screen is active
    echo "${CYAN}Configure brightness for when the screen is active.${NC}"
    echo "${CYAN}Suggested range is 150-255, where 255 is maximum brightness.${NC}"
    while true; do
        read -p "${MAGENTA}Enter brightness for active screen (default is $current_on_value): ${NC}" on_value
        # Use default if empty
        on_value=${on_value:-$current_on_value}
        
        # Validate brightness is a number between 0-255
        if ! [[ "$on_value" =~ ^[0-9]+$ ]] || [ "$on_value" -lt 0 ] || [ "$on_value" -gt 255 ]; then
            echo "${RED}Invalid brightness value. Must be between 0 and 255.${NC}"
            continue
        fi
        
        # Preview the brightness
        echo "${YELLOW}Setting brightness to $on_value for preview...${NC}"
        sudo ./scripts/brightness.sh $on_value
        
        read -p "${MAGENTA}Is this brightness good? (Y/n): ${NC}" is_good
        if [[ "$is_good" != "n" && "$is_good" != "N" ]]; then
            # Update the on_value in the file using a safer approach
            if [ -f ./scripts/motion_brightness.py ]; then
                if python3 -c "
import re
import sys
with open('./scripts/motion_brightness.py', 'r') as f:
    content = f.read()
new_content = re.sub(r\"--on-value',\s*type=str,\s*default=\\\"[0-9]+\\\"\", 
                     \"--on-value', type=str, default=\\\"$on_value\\\"\", content)
if content == new_content:
    print('Warning: Pattern not found, on-value may not have been updated', file=sys.stderr)
    sys.exit(1)
with open('./scripts/motion_brightness.py', 'w') as f:
    f.write(new_content)
"; then
                    echo "${GREEN}On-value brightness updated successfully.${NC}"
                else
                    echo "${RED}Warning: Could not update on-value in motion_brightness.py${NC}"
                fi
            fi
            break
        fi
    done
    
    # If motion detection is enabled, configure dimmed brightness
    if [ "$use_motion" = true ]; then
        echo "${CYAN}Configure brightness for when the screen is dimmed (after $timeout seconds of inactivity).${NC}"
        echo "${CYAN}Suggested value is 0 (screen off), but you can choose any value from 0-255.${NC}"
        while true; do
            read -p "${MAGENTA}Enter brightness for dimmed screen (default is $current_off_value): ${NC}" off_value
            # Use default if empty
            off_value=${off_value:-$current_off_value}
            
            # Validate brightness is a number between 0-255
            if ! [[ "$off_value" =~ ^[0-9]+$ ]] || [ "$off_value" -lt 0 ] || [ "$off_value" -gt 255 ]; then
                echo "${RED}Invalid brightness value. Must be between 0 and 255.${NC}"
                continue
            fi
            
            # Preview the brightness for 10 seconds
            echo "${YELLOW}Setting brightness to $off_value for preview (10 seconds)...${NC}"
            sudo ./scripts/brightness.sh $off_value
            echo "${YELLOW}Previewing dimmed brightness for 10 seconds...${NC}"
            sleep 10
            
            # Return to normal brightness
            sudo ./scripts/brightness.sh $on_value
            
            read -p "${MAGENTA}Is this dimmed brightness good? (Y/n): ${NC}" is_good
            if [[ "$is_good" != "n" && "$is_good" != "N" ]]; then
                # Update the off_value in the file using a safer approach
                if [ -f ./scripts/motion_brightness.py ]; then
                    if python3 -c "
import re
import sys
with open('./scripts/motion_brightness.py', 'r') as f:
    content = f.read()
new_content = re.sub(r\"--off-value',\s*type=str,\s*default=\\\"[0-9]+\\\"\", 
                     \"--off-value', type=str, default=\\\"$off_value\\\"\", content)
if content == new_content:
    print('Warning: Pattern not found, off-value may not have been updated', file=sys.stderr)
    sys.exit(1)
with open('./scripts/motion_brightness.py', 'w') as f:
    f.write(new_content)
"; then
                        echo "${GREEN}Off-value brightness updated successfully.${NC}"
                    else
                        echo "${RED}Warning: Could not update off-value in motion_brightness.py${NC}"
                    fi
                fi
                break
            fi
        done
    else
        # If motion detection is disabled, set both brightness values to the same
        if [ -f ./scripts/motion_brightness.py ]; then
            if python3 -c "
import re
import sys
with open('./scripts/motion_brightness.py', 'r') as f:
    content = f.read()
new_content = re.sub(r\"--off-value',\s*type=str,\s*default=\\\"[0-9]+\\\"\", 
                     \"--off-value', type=str, default=\\\"$on_value\\\"\", content)
if content == new_content:
    print('Warning: Pattern not found, off-value may not have been updated', file=sys.stderr)
    sys.exit(1)
with open('./scripts/motion_brightness.py', 'w') as f:
    f.write(new_content)
"; then
                echo "${GREEN}Off-value brightness set to match on-value.${NC}"
            else
                echo "${RED}Warning: Could not update off-value in motion_brightness.py${NC}"
            fi
        fi
    fi
    
    # Always set brightness back to on_value at the end
    sudo ./scripts/brightness.sh $on_value
    
    echo "${GREEN}Motion detection settings configured.${NC}"
    
    # Set global variable for motion detection status
    if [ "$use_motion" = true ]; then
        MOTION_STATUS="enable_motion"
        echo "${GREEN}Motion detection will start automatically on boot.${NC}"
    else
        MOTION_STATUS="disable_motion"
        echo "${YELLOW}Motion detection will not start automatically.${NC}"
    fi
}

# Check if motion_brightness.py exists
if [ -f ./scripts/motion_brightness.py ]; then
    read -p "${MAGENTA}Do you want to configure motion detection and brightness settings? (y/N): ${NC}" reconfigure_motion
    if [[ "$reconfigure_motion" == "y" || "$reconfigure_motion" == "Y" ]]; then
        setup_motion_brightness
    else
        echo "${GREEN}Keeping existing motion detection settings.${NC}"
    fi
else
    setup_motion_brightness
fi

# Run cronJobs.sh only once with the appropriate parameter if needed
if [ -n "$MOTION_STATUS" ]; then
    ./scripts/cronJobs.sh "$MOTION_STATUS"
else
    ./scripts/cronJobs.sh
fi

./scripts/rainbow.sh "Setup complete!"