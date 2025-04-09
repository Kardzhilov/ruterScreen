#!/bin/bash

# Path to the config file
CONFIG_FILE="/boot/firmware/config.txt"

# Function to display the menu
display_menu() {
    echo "Select the display rotation value:"
    echo "0 - Default Orientation"
    echo "1 - Rotate 270° Clockwise"
    echo "2 - Rotate 180°"
    echo "3 - Rotate 90° Clockwise"
}

# Function to prompt the user for the display rotation value
prompt_for_rotation() {
    while true; do
        read -p "Enter the rotation value (0, 1, 2, or 3): " rotation_value
        case $rotation_value in
            0|1|2|3)
                echo "$rotation_value"
                return
                ;;
            *)
                echo "Invalid input. Please enter 0, 1, 2, or 3."
                ;;
        esac
    done
}

# Check if the display_rotate line is already present in the config file
if grep -q "^display_rotate=" "$CONFIG_FILE"; then
    current_rotation=$(grep "^display_rotate=" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '\n')
    echo "Current display rotation value: $current_rotation"
    read -p "Do you want to change the display rotation value? (y/N): " change_rotation
    if [[ "$change_rotation" == "y" || "$change_rotation" == "Y" ]]; then
        display_menu
        new_rotation=$(prompt_for_rotation)
        sudo sed -i "/^display_rotate=/c\display_rotate=$new_rotation" "$CONFIG_FILE"
        echo "The display rotation value has been updated to $new_rotation."
    else
        echo "No changes made to the display rotation value."
    fi
else
    echo "The display_rotate line is not present in $CONFIG_FILE. Adding it to the top of the file."
    display_menu
    new_rotation=$(prompt_for_rotation)
    # Backup the current config file
    sudo cp "$CONFIG_FILE" "$CONFIG_FILE.bak"
    # Add the line to the top of the config file
    echo "display_rotate=$new_rotation" | sudo tee "$CONFIG_FILE.new" > /dev/null
    sudo cat "$CONFIG_FILE" >> "$CONFIG_FILE.new"
    sudo mv "$CONFIG_FILE.new" "$CONFIG_FILE"
    echo "The line 'display_rotate=$new_rotation' has been added to the top of $CONFIG_FILE."
    echo "Note you need toreboot the system to see the changes."
fi