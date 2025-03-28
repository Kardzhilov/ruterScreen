#!/bin/bash

# Source the colors file
source ./scripts/colours.sh

echo "${CYAN}Starting setup...${NC}"

# Run departures.sh script
# ./scripts/departures.sh 

# Set up screen orientation
echo "${CYAN}Setting up screen orientation...${NC}"
# sudo ./scripts/screenOrentation.sh

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

./scripts/cronJobs.sh

./scripts/rainbow.sh "Setup complete!"