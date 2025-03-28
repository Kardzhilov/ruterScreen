#!/bin/bash

# Source the colors file
source ./scripts/colours.sh

# Define the rainbow colors sequence
RAINBOW=(
    "$RED"
    "$ORANGE"
    "$YELLOW"
    "$LIME_GREEN"
    "$GREEN"
    "$CYAN"
    "$SKY_BLUE"
    "$BLUE"
    "$PURPLE"
    "$MAGENTA"
    "$PINK"
)

# Function to print rainbow text
print_rainbow() {
    local text="$1"
    local len=${#text}
    for ((i=0; i<len; i++)); do
        local char="${text:$i:1}"
        local color_index=$((i % ${#RAINBOW[@]}))
        echo -n "${RAINBOW[$color_index]}$char${NC}"
    done
    echo
}

# Check if an argument is passed
if [ $# -eq 0 ]; then
    echo "Usage: $0 <text>"
    exit 1
fi

# Echo message in rainbow colors
print_rainbow "$1"
