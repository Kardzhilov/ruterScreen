#!/bin/bash

# Get the directory where this script resides
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Define the paths to the scripts relative to this script's location
LAUNCH_SCRIPT="$SCRIPT_DIR/launchSite.sh"
MOTION_SCRIPT="$SCRIPT_DIR/motion_brightness.py"

# Define the log file path
LOG_FILE="$SCRIPT_DIR/firefox.log"

# Define the cronjobs
CRONJOB_LAUNCH="@reboot sleep 60 && $LAUNCH_SCRIPT >> $LOG_FILE 2>&1"
CRONJOB_RESTART="0 */10 * * * $LAUNCH_SCRIPT >> $LOG_FILE 2>&1"
CRONJOB_MOTION="@reboot sleep 30 && sudo python3 $MOTION_SCRIPT"

# Function to check if a cronjob exists
cronjob_exists() {
  crontab -l 2>/dev/null | grep -Fx "$1" >/dev/null
}

# Set up the basic cron jobs (always do this)
setup_basic_cronjobs() {
  # Check if the @reboot cronjob for launchSite already exists
  if cronjob_exists "$CRONJOB_LAUNCH"; then
    echo "Cronjob for launchSite.sh at startup already exists. No changes made."
  else
    # Add the @reboot cronjob
    (crontab -l 2>/dev/null; echo "$CRONJOB_LAUNCH") | crontab -
    echo "Cronjob for launchSite.sh at startup added successfully."
  fi

  # Remove any existing refre.sh cronjobs
  current_crontab=$(crontab -l 2>/dev/null | grep -v "$SCRIPT_DIR/refre.sh")
  echo "$current_crontab" | crontab -

  # Check if the every-10-hours cronjob already exists
  if cronjob_exists "$CRONJOB_RESTART"; then
    echo "Cronjob for launchSite.sh every 10 hours already exists. No changes made."
  else
    # Add the every-10-hours cronjob
    (crontab -l 2>/dev/null; echo "$CRONJOB_RESTART") | crontab -
    echo "Cronjob for launchSite.sh every 10 hours added successfully."
  fi
}

# Always set up the basic cron jobs
setup_basic_cronjobs

# Handle motion detection cronjob based on argument
if [ "$1" = "enable_motion" ]; then
  # Remove any existing motion detection cronjobs
  current_crontab=$(crontab -l 2>/dev/null | grep -v "motion_brightness.py")
  echo "$current_crontab" | crontab -
  
  # Add the motion detection cronjob
  (crontab -l 2>/dev/null; echo "$CRONJOB_MOTION") | crontab -
  echo "Cronjob for motion_brightness.py added successfully."
elif [ "$1" = "disable_motion" ]; then
  # Remove any existing motion detection cronjobs
  current_crontab=$(crontab -l 2>/dev/null | grep -v "motion_brightness.py")
  echo "$current_crontab" | crontab -
  echo "Cronjob for motion_brightness.py removed."
fi