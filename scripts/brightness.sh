#!/bin/bash

# Script to smoothly change the brightness of the screen

# Path to the backlight brightness file
BRIGHTNESS_FILE="/sys/class/backlight/*/brightness"

# Function to get current brightness
get_current_brightness() {
    local brightness_path=$(echo $BRIGHTNESS_FILE | sed 's/\*/intel_backlight/g')
    if [ ! -f "$brightness_path" ]; then
        brightness_path=$(ls /sys/class/backlight/*/brightness 2>/dev/null | head -n 1)
    fi

    if [ -f "$brightness_path" ]; then
        cat "$brightness_path"
    else
        echo "Error: Cannot find brightness file" >&2
        exit 1
    fi
}

# Function to smoothly change brightness from start to end
smooth_brightness_change() {
    local start=$1
    local end=$2
    local target_duration=2.0      # Target duration in seconds

    local diff=$(( $start > $end ? $start - $end : $end - $start ))
    local steps=20
    local step_size=$(( ($diff + $steps - 1) / $steps ))

    if [ $step_size -lt 1 ]; then
        step_size=1
    fi
    local interval=$(echo "$target_duration / $steps" | bc -l)

    if [ "$start" -lt "$end" ]; then
        local values=()
        local current=$start
        for ((i=0; i<$steps; i++)); do
            values+=($current)
            current=$(( $current + $step_size ))
            if [ $current -gt $end ]; then
                current=$end
            fi
        done
        if [ ${values[-1]} -ne $end ]; then
            values+=($end)
        fi

        for value in "${values[@]}"; do
            echo $value | sudo tee $BRIGHTNESS_FILE > /dev/null
            sleep $interval
        done
    else
        local values=()
        local current=$start
        for ((i=0; i<$steps; i++)); do
            values+=($current)
            current=$(( $current - $step_size ))
            if [ $current -lt $end ]; then
                current=$end
            fi
        done
        if [ ${values[-1]} -ne $end ]; then
            values+=($end)
        fi

        for value in "${values[@]}"; do
            echo $value | sudo tee $BRIGHTNESS_FILE > /dev/null
            sleep $interval
        done
    fi
}

# Check if target brightness is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <target_brightness>"
    echo "  <target_brightness> should be between 0 and 255"
    exit 1
fi

# Get the target brightness
target_brightness=$1

# Validate target brightness
if ! [[ $target_brightness =~ ^[0-9]+$ ]]; then
    echo "Error: Target brightness must be a number"
    exit 1
fi

if [ $target_brightness -lt 0 ] || [ $target_brightness -gt 255 ]; then
    echo "Error: Target brightness must be between 0 and 255"
    exit 1
fi

# Get current brightness
current_brightness=$(get_current_brightness)
echo "Current brightness: $current_brightness"
echo "Target brightness: $target_brightness"

# Check if change is needed
if [ "$current_brightness" -eq "$target_brightness" ]; then
    echo "Brightness already at target level. No change needed."
    exit 0
fi

# Smoothly change brightness
smooth_brightness_change $current_brightness $target_brightness

echo "Brightness adjustment complete"