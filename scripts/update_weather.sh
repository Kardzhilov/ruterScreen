#!/bin/bash

# Source the colors file
source ./scripts/colours.sh

# Function to configure weather location ID
configure_weather_location() {
    echo ""
    echo "${CYAN}Weather widget location options:${NC}"
    echo "${YELLOW}1. Oslo, Norway (wl8757)${NC} - Default location"
    echo "${YELLOW}2. Custom location ID${NC} - Enter your own weatherwidget.org location ID"
    echo ""
    echo "${CYAN}To find your custom location ID:${NC}"
    echo "${CYAN}  - Go to https://weatherwidget.org/${NC}"
    echo "${CYAN}  - Search for your city${NC}"
    echo "${CYAN}  - Copy the location ID (e.g., 'wl1234') from the widget code${NC}"
    echo ""

    read -p "${MAGENTA}Select an option (1-2) or press Enter to keep current: ${NC}" choice

    case $choice in
        1)
            new_weather_location_id="wl8757"
            echo "${GREEN}Selected: Oslo, Norway (wl8757)${NC}"
            ;;
        2)
            read -p "${MAGENTA}Enter your weatherwidget.org location ID (e.g., wl1234): ${NC}" new_weather_location_id
            if [[ -z "$new_weather_location_id" ]]; then
                echo "${RED}Location ID cannot be empty. No changes made.${NC}"
                return
            fi
            echo "${GREEN}Selected: Custom location ($new_weather_location_id)${NC}"
            ;;
        "")
            echo "${GREEN}Keeping current weather location ID.${NC}"
            return
            ;;
        *)
            echo "${RED}Invalid option. No changes made.${NC}"
            return
            ;;
    esac

    if [ -n "$new_weather_location_id" ]; then
        # Update the weather location ID in launchSite.sh
        sed -i "s|^WEATHER_LOCATION_ID=\".*\"|WEATHER_LOCATION_ID=\"$new_weather_location_id\"|" ./scripts/launchSite.sh
        echo "${GREEN}Weather location ID updated to: $new_weather_location_id${NC}"
    else
        echo "${RED}No location ID provided. No changes made.${NC}"
    fi
}

echo "${CYAN}RuterScreen Display Configuration${NC}"
echo ""

# Check if launchSite.sh exists
if [ ! -f ./scripts/launchSite.sh ]; then
    echo "${RED}Error: launchSite.sh not found. Please run setup.sh first.${NC}"
    exit 1
fi

# Extract current settings
current_display_mode=$(grep '^DISPLAY_MODE=' ./scripts/launchSite.sh | cut -d '"' -f 2)
current_weather_location_id=$(grep '^WEATHER_LOCATION_ID=' ./scripts/launchSite.sh | cut -d '"' -f 2)

echo "${GREEN}Current configuration:${NC}"
if [ "$current_display_mode" = "timetable" ]; then
    echo "  Display mode: Timetable only"
else
    echo "  Display mode: Combined (weather + timetable)"
    if [ -n "$current_weather_location_id" ]; then
        echo "  Weather Location ID: $current_weather_location_id"
    fi
fi
echo ""

echo "${CYAN}What would you like to configure?${NC}"
echo "${YELLOW}1. Change display mode${NC}"
echo "${YELLOW}2. Update weather location ID${NC} (only for combined mode)"
echo "${YELLOW}3. Exit${NC}"
echo ""

read -p "${MAGENTA}Select an option (1-3): ${NC}" main_choice

case $main_choice in
    1)
        echo ""
        echo "${CYAN}Select display mode:${NC}"
        echo "${YELLOW}1. Timetable only${NC} - Full screen Ruter timetable"
        echo "${YELLOW}2. Combined display${NC} - Weather forecast (top) + Ruter timetable (bottom)"
        echo ""
        
        read -p "${MAGENTA}Select mode (1 or 2): ${NC}" mode_choice
        case $mode_choice in
            1)
                new_display_mode="timetable"
                sed -i "s|^DISPLAY_MODE=\".*\"|DISPLAY_MODE=\"$new_display_mode\"|" ./scripts/launchSite.sh
                echo "${GREEN}Display mode updated to: Timetable only${NC}"
                ;;
            2)
                new_display_mode="combined"
                sed -i "s|^DISPLAY_MODE=\".*\"|DISPLAY_MODE=\"$new_display_mode\"|" ./scripts/launchSite.sh
                echo "${GREEN}Display mode updated to: Combined (weather + timetable)${NC}"
                
                # If switching to combined mode, offer to configure weather location ID
                if [ "$current_display_mode" = "timetable" ]; then
                    echo ""
                    read -p "${MAGENTA}Would you like to configure the weather location ID now? (Y/n): ${NC}" config_weather
                    if [[ "$config_weather" != "n" && "$config_weather" != "N" ]]; then
                        configure_weather_location
                    fi
                fi
                ;;
            *)
                echo "${RED}Invalid option. No changes made.${NC}"
                exit 1
                ;;
        esac
        ;;
    2)
        if [ "$current_display_mode" = "timetable" ]; then
            echo "${YELLOW}Weather location ID configuration is only available in combined display mode.${NC}"
            echo "${YELLOW}Switch to combined mode first to configure weather location ID.${NC}"
            exit 1
        fi
        configure_weather_location
        ;;
    3)
        echo "${GREEN}Exiting without changes.${NC}"
        exit 0
        ;;
    *)
        echo "${RED}Invalid option. Exiting.${NC}"
        exit 1
        ;;
esac

echo "${YELLOW}Changes will take effect the next time the display is launched.${NC}"
