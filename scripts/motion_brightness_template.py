#!/usr/bin/env python3
"""
Motion-activated screen brightness controller
Usage: sudo python motion_brightness.py [options]

Options:
  --timeout SECONDS     Time with no motion before turning off screen (default: 120)
  --on-value VALUE      Brightness value when turning on (default: 255)
  --off-value VALUE     Brightness value when turning off (default: 0)
  --log-file PATH       Path to log file (default: ~/motion_detector.log)
"""

import RPi.GPIO as GPIO
import time
import datetime
import subprocess
import os
import sys
import argparse
import logging
from pathlib import Path

def parse_arguments():
    """Parse command line arguments"""
    # Get default log file path in user's home directory
    default_log = str(Path.home() / "motion_detector.log")
    
    parser = argparse.ArgumentParser(description='Motion-activated screen brightness controller')
    parser.add_argument('--timeout', type=int, default=120,
                        help='Time with no motion before turning off screen (default: 120)')
    parser.add_argument('--on-value', type=str, default="255",
                        help='Brightness value when turning on (default: 255)')
    parser.add_argument('--off-value', type=str, default="0",
                        help='Brightness value when turning off (default: 0)')
    parser.add_argument('--log-file', type=str, default=default_log,
                        help=f'Path to log file (default: {default_log})')
    return parser.parse_args()

def setup_logging(log_file):
    """Configure logging to file and console"""
    # Create a logger
    logger = logging.getLogger('motion_detector')
    logger.setLevel(logging.INFO)
    
    # Create handlers
    file_handler = logging.FileHandler(log_file)
    console_handler = logging.StreamHandler()
    
    # Create formatter and add it to the handlers
    formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
    file_handler.setFormatter(formatter)
    console_handler.setFormatter(formatter)
    
    # Add handlers to logger
    logger.addHandler(file_handler)
    logger.addHandler(console_handler)
    
    return logger

def main():
    """Main function"""
    # Get arguments
    args = parse_arguments()
    
    # Setup logging
    logger = setup_logging(args.log_file)
    
    # Log startup information
    logger.info("="*50)
    logger.info("Motion Detector started")
    logger.info(f"Process ID: {os.getpid()}")
    logger.info(f"Started by user: {os.getlogin() if hasattr(os, 'getlogin') else 'unknown'}")
    logger.info(f"Running from: {os.path.abspath(__file__)}")
    logger.info(f"Timeout: {args.timeout} seconds")
    logger.info(f"ON brightness: {args.on_value}")
    logger.info(f"OFF brightness: {args.off_value}")
    logger.info(f"Log file: {args.log_file}")
    
    # Fixed values
    PIR_PIN = 24  # Fixed pin for PIR sensor
    logger.info(f"PIR sensor pin: GPIO {PIR_PIN}")
    
    # Get the directory of this script
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Fixed path to brightness script
    brightness_script = os.path.join(script_dir, "brightness.sh")
    logger.info(f"Brightness script: {brightness_script}")
    
    # Check if brightness script exists
    if not os.path.isfile(brightness_script):
        logger.error(f"Error: Brightness script not found at {brightness_script}")
        sys.exit(1)
    
    # Configure GPIO
    try:
        GPIO.setmode(GPIO.BCM)
        GPIO.setwarnings(False)
        GPIO.setup(PIR_PIN, GPIO.IN, pull_up_down=GPIO.PUD_DOWN)
        logger.info("GPIO configured successfully")
    except Exception as e:
        logger.error(f"Error configuring GPIO: {str(e)}")
        sys.exit(1)
    
    # Initial state
    last_motion_time = time.time()
    screen_on = True  # Start with screen ON by default
    motion_count = 0  # Track number of motion detections
    
    # Set initial screen brightness to ON
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    logger.info(f"Starting with screen ON")
    try:
        subprocess.run(["sudo", brightness_script, args.on_value], check=True)
        logger.info(f"Screen brightness set to {args.on_value}")
    except subprocess.SubprocessError as e:
        logger.error(f"Error setting initial brightness: {str(e)}")
    
    logger.info("Monitoring for motion...")
    
    try:
        while True:
            current_time = time.time()
            
            # Check if motion is detected
            if GPIO.input(PIR_PIN):
                # Motion detected
                motion_count += 1
                last_motion_time = current_time
                
                # Turn screen on if it's not already on
                if not screen_on:
                    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                    logger.info(f"Motion detected! Turning screen ON (detection #{motion_count})")
                    try:
                        subprocess.run(["sudo", brightness_script, args.on_value], check=True)
                        screen_on = True
                    except subprocess.SubprocessError as e:
                        logger.error(f"Error turning screen ON: {str(e)}")
                elif motion_count % 100 == 0:  # Log occasionally to show it's still working
                    logger.info(f"Motion detected (detection #{motion_count}), screen already ON")
            
            # Check if no motion for specified timeout
            elif (current_time - last_motion_time > args.timeout) and screen_on:
                # No motion for timeout period, turn off screen
                elapsed = int(current_time - last_motion_time)
                timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                logger.info(f"No motion for {elapsed} seconds. Turning screen OFF")
                try:
                    subprocess.run(["sudo", brightness_script, args.off_value], check=True)
                    screen_on = False
                except subprocess.SubprocessError as e:
                    logger.error(f"Error turning screen OFF: {str(e)}")
            
            # Small delay to prevent CPU overload
            time.sleep(0.2)
            
    except KeyboardInterrupt:
        logger.info("Program ended by user")
        # Make sure to turn screen back on when exiting
        try:
            subprocess.run(["sudo", brightness_script, args.on_value], check=True)
            logger.info("Screen brightness restored to ON value")
        except subprocess.SubprocessError as e:
            logger.error(f"Error restoring brightness: {str(e)}")
        
        GPIO.cleanup()
        logger.info("GPIO cleaned up")
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        # Try to clean up even if there's an error
        try:
            GPIO.cleanup()
            logger.info("GPIO cleaned up after error")
        except:
            pass
        
        # Try to restore screen brightness
        try:
            subprocess.run(["sudo", brightness_script, args.on_value])
            logger.info("Screen brightness restored after error")
        except:
            pass

if __name__ == "__main__":
    main() 