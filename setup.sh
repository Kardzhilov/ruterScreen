#!/bin/bash

# Source the colors file
source ./scripts/colours.sh

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

# Extract the current URL from launchSite.sh
current_url=$(grep '^URL=' ./scripts/launchSite.sh | cut -d '"' -f 2)
if [ -n "$current_url" ]; then
    read -p "${MAGENTA}The current URL is set to '$current_url'. Do you want to update it? (y/N): ${NC}" update
    if [[ "$update" == "y" || "$update" == "Y" ]]; then
        echo "${CYAN}Time to set the Ruter URL for your custom stop.${NC}"
        echo "${CYAN}Go to https://mon.ruter.no/ and fill out/customize your stop.${NC}"
        echo "${CYAN}Once you have set up your custom stop, copy and paste the whole URL into this terminal.${NC}"
        read -p "${MAGENTA}URL: ${NC}" url

        # Replace the placeholder URL in launchSite.sh
        sed -i "s|^URL=\".*\"|URL=\"$url\"|" ./scripts/launchSite.sh
    else
        echo "${GREEN}Skipping URL update.${NC}"
    fi
else
    echo "${YELLOW}No URL found in launchSite.sh. Setting a new URL.${NC}"
    echo "${CYAN}Time to set the Ruter URL for your custom stop.${NC}"
    echo "${CYAN}Go to https://mon.ruter.no/ and fill out/customize your stop.${NC}"
    echo "${CYAN}Once you have set up your custom stop, copy and paste the whole URL into this terminal.${NC}"
    read -p "${MAGENTA}URL: ${NC}" url

    # Replace the placeholder URL in launchSite.sh
    sed -i "s|^URL=\".*\"|URL=\"$url\"|" ./scripts/launchSite.sh
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
        current_timeout=$(grep -oP 'default=\K[0-9]+(?=.*Time with no motion)' ./scripts/motion_brightness.py)
        current_on_value=$(grep -oP 'default="\K[0-9]+(?=".*Brightness value when turning on)' ./scripts/motion_brightness.py)
        current_off_value=$(grep -oP 'default="\K[0-9]+(?=".*Brightness value when turning off)' ./scripts/motion_brightness.py)
    else
        current_timeout=120
        current_on_value=255
        current_off_value=0
    fi
    
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
        
        # Update the timeout in the file
        sed -i "s/--timeout', type=int, default=[0-9]\+/--timeout', type=int, default=$timeout/" ./scripts/motion_brightness.py
        echo "${GREEN}Timeout set to $timeout seconds.${NC}"
    fi
    
    # Configure brightness when screen is active
    echo "${CYAN}Configure brightness for when the screen is active.${NC}"
    echo "${CYAN}Suggested range is 150-255, where 255 is maximum brightness.${NC}"
    while true; do
        read -p "${MAGENTA}Enter brightness for active screen (default is $current_on_value): ${NC}" on_value
        # Use default if empty
        on_value=${on_value:-$current_on_value}
        
        # Preview the brightness
        echo "${YELLOW}Setting brightness to $on_value for preview...${NC}"
        sudo ./scripts/brightness.sh $on_value
        
        read -p "${MAGENTA}Is this brightness good? (Y/n): ${NC}" is_good
        if [[ "$is_good" != "n" && "$is_good" != "N" ]]; then
            # Update the on_value in the file
            sed -i "s/--on-value', type=str, default=\"[0-9]\+\"/--on-value', type=str, default=\"$on_value\"/" ./scripts/motion_brightness.py
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
            
            # Preview the brightness for 10 seconds
            echo "${YELLOW}Setting brightness to $off_value for preview (10 seconds)...${NC}"
            sudo ./scripts/brightness.sh $off_value
            echo "${YELLOW}Previewing dimmed brightness for 10 seconds...${NC}"
            sleep 10
            
            # Return to normal brightness
            sudo ./scripts/brightness.sh $on_value
            
            read -p "${MAGENTA}Is this dimmed brightness good? (Y/n): ${NC}" is_good
            if [[ "$is_good" != "n" && "$is_good" != "N" ]]; then
                # Update the off_value in the file
                sed -i "s/--off-value', type=str, default=\"[0-9]\+\"/--off-value', type=str, default=\"$off_value\"/" ./scripts/motion_brightness.py
                break
            fi
        done
    else
        # If motion detection is disabled, set both brightness values to the same
        sed -i "s/--off-value', type=str, default=\"[0-9]\+\"/--off-value', type=str, default=\"$on_value\"/" ./scripts/motion_brightness.py
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