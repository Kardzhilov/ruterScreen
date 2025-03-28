#!/bin/bash

# Get the directory where this script resides
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Define the paths to the scripts relative to this script's location
LAUNCH_SCRIPT="$SCRIPT_DIR/launchSite.sh"
REFRE_SCRIPT="$SCRIPT_DIR/refre.sh"

# Define the log file path
LOG_FILE="$SCRIPT_DIR/firefox.log"

# Define the cronjobs
CRONJOB_LAUNCH="@reboot sleep 60 && $LAUNCH_SCRIPT >> $LOG_FILE 2>&1"
CRONJOB_REFRE="0 */3 * * * $REFRE_SCRIPT >> $LOG_FILE 2>&1"

# Function to check if a cronjob exists
cronjob_exists() {
  crontab -l 2>/dev/null | grep -Fx "$1" >/dev/null
}

# Check if the @reboot cronjob already exists
if cronjob_exists "$CRONJOB_LAUNCH"; then
  echo "Cronjob for launchSite.sh already exists. No changes made."
else
  # Add the @reboot cronjob
  (crontab -l 2>/dev/null; echo "$CRONJOB_LAUNCH") | crontab -
  echo "Cronjob for launchSite.sh added successfully."
fi

# Check if the every-3-hours cronjob already exists
if cronjob_exists "$CRONJOB_REFRE"; then
  echo "Cronjob for refre.sh already exists. No changes made."
else
  # Add the every-3-hours cronjob
  (crontab -l 2>/dev/null; echo "$CRONJOB_REFRE") | crontab -
  echo "Cronjob for refre.sh added successfully."
fi