#!/usr/bin/env python3
"""
Motion-activated screen brightness controller
Usage: sudo python motion_brightness.py [options]

Options:
  --timeout SECONDS     Time with no motion before turning off screen (default: 120)
  --on-value VALUE      Brightness value when turning on (default: 255)
  --off-value VALUE     Brightness value when turning off (default: 0)
"""

import RPi.GPIO as GPIO
import time
import datetime
import subprocess
import os
import sys
import argparse

def parse_arguments():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description='Motion-activated screen brightness controller')
    parser.add_argument('--timeout', type=int, default=120,
                        help='Time with no motion before turning off screen (default: 120)')
    parser.add_argument('--on-value', type=str, default="255",
                        help='Brightness value when turning on (default: 255)')
    parser.add_argument('--off-value', type=str, default="0",
                        help='Brightness value when turning off (default: 0)')
    return parser.parse_args()

def main():
    """Main function"""
    # Get arguments
    args = parse_arguments()
    
    # Fixed values
    PIR_PIN = 24  # Fixed pin for PIR sensor
    
    # Get the directory of this script
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Fixed path to brightness script
    brightness_script = os.path.join(script_dir, "brightness.sh")
    
    # Check if brightness script exists
    if not os.path.isfile(brightness_script):
        print(f"Error: Brightness script not found at {brightness_script}")
        sys.exit(1)
    
    # Configure GPIO
    GPIO.setmode(GPIO.BCM)
    GPIO.setwarnings(False)
    GPIO.setup(PIR_PIN, GPIO.IN, pull_up_down=GPIO.PUD_DOWN)
    
    # Initial state
    last_motion_time = time.time()
    screen_on = False
    
    print(f"Motion Detector with Brightness Control")
    print(f"----------------------------------------")
    print(f"PIR Sensor: GPIO {PIR_PIN}")
    print(f"Timeout: {args.timeout} seconds")
    print(f"Brightness Script: {brightness_script}")
    print(f"Brightness ON Value: {args.on_value}")
    print(f"Brightness OFF Value: {args.off_value}")
    print(f"----------------------------------------")
    print("Press CTRL+C to exit")
    
    try:
        while True:
            current_time = time.time()
            
            # Check if motion is detected
            if GPIO.input(PIR_PIN):
                # Motion detected
                last_motion_time = current_time
                
                # Turn screen on if it's not already on
                if not screen_on:
                    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                    print(f"Motion detected! Turning screen ON at {timestamp}")
                    subprocess.run(["sudo", brightness_script, args.on_value])
                    screen_on = True
            
            # Check if no motion for specified timeout
            elif (current_time - last_motion_time > args.timeout) and screen_on:
                # No motion for timeout period, turn off screen
                timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                print(f"No motion for {args.timeout} seconds. Turning screen OFF at {timestamp}")
                subprocess.run(["sudo", brightness_script, args.off_value])
                screen_on = False
            
            # Small delay to prevent CPU overload
            time.sleep(0.2)
            
    except KeyboardInterrupt:
        print("Program ended by user")
        # Make sure to turn screen back on when exiting
        subprocess.run(["sudo", brightness_script, args.on_value])
        GPIO.cleanup()

if __name__ == "__main__":
    main() 