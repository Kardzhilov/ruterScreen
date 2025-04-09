#!/usr/bin/env python3
"""
PIR Sensor Test Utility

This script helps verify that a PIR motion sensor is properly connected
to the Raspberry Pi. It first tests the default pin (GPIO 24), and if
no motion is detected, it can monitor all available GPIO pins simultaneously.

Usage: sudo python3 pir_test.py
"""

import RPi.GPIO as GPIO
import time
import sys
import argparse
import os
from threading import Thread
from collections import defaultdict

# Define color codes for terminal output
class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    MAGENTA = '\033[35m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'

# Default pin for PIR sensor
DEFAULT_PIN = 24

# List of GPIO pins to test (excluding power and ground pins)
# These are BCM numbers, not physical pin numbers, in ascending order
AVAILABLE_PINS = [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27]

def setup_gpio():
    """Set up GPIO and clean any previous configurations"""
    GPIO.setwarnings(False)
    GPIO.setmode(GPIO.BCM)
    GPIO.cleanup()

def test_pin(pin, test_duration=5):
    """
    Test a specific pin for PIR sensor activity
    Returns: Number of motion detections
    """
    GPIO.setup(pin, GPIO.IN, pull_up_down=GPIO.PUD_DOWN)
    
    print(f"Testing GPIO {pin} for {test_duration} seconds...")
    print(f"{Colors.YELLOW}Move in front of the PIR sensor now!{Colors.ENDC}")
    
    # Wait for sensor to settle
    time.sleep(0.5)
    
    # Monitor for motion
    motion_count = 0
    start_time = time.time()
    while time.time() - start_time < test_duration:
        if GPIO.input(pin):
            motion_count += 1
            print(f"{Colors.GREEN}Motion detected on GPIO {pin}!{Colors.ENDC}")
            # Wait a bit to avoid counting the same motion multiple times
            time.sleep(0.5)
        time.sleep(0.1)
        
    return motion_count

def monitor_pin(pin, results, stop_event):
    """
    Function to monitor a single pin for motion in a separate thread
    """
    try:
        GPIO.setup(pin, GPIO.IN, pull_up_down=GPIO.PUD_DOWN)
        last_state = GPIO.input(pin)
        
        while not stop_event.is_set():
            current_state = GPIO.input(pin)
            
            # If state changed from LOW to HIGH, motion detected
            if current_state and not last_state:
                results[pin] += 1
                print(f"{Colors.GREEN}Motion detected on GPIO {pin}!{Colors.ENDC}")
                
            last_state = current_state
            time.sleep(0.05)  # Short delay to avoid CPU overload
            
    except Exception as e:
        print(f"Error monitoring GPIO {pin}: {str(e)}")

def monitor_all_pins_simultaneously(test_duration=20):
    """
    Monitor all pins simultaneously for motion detection
    Returns: Dictionary of pins and their detection counts
    """
    from threading import Event
    
    # Dictionary to hold detection counts for each pin
    results = defaultdict(int)
    threads = []
    stop_event = Event()
    
    print(f"\n{Colors.CYAN}Monitoring all available GPIO pins simultaneously...{Colors.ENDC}")
    print(f"{Colors.YELLOW}Move in front of the PIR sensor now!{Colors.ENDC}")
    print(f"This will run for {test_duration} seconds.\n")
    
    # Start a monitoring thread for each pin
    for pin in AVAILABLE_PINS:
        try:
            thread = Thread(target=monitor_pin, args=(pin, results, stop_event))
            thread.daemon = True
            thread.start()
            threads.append(thread)
        except Exception as e:
            print(f"Could not monitor GPIO {pin}: {str(e)}")
    
    # Print a countdown timer
    start_time = time.time()
    remaining = test_duration
    while remaining > 0:
        mins, secs = divmod(remaining, 60)
        timeformat = f"{int(mins):02d}:{int(secs):02d}"
        print(f"\rTime remaining: {timeformat}", end="")
        time.sleep(1)
        remaining = test_duration - (time.time() - start_time)
    
    # Stop all monitoring threads
    stop_event.set()
    print("\n\nMonitoring complete!")
    
    return dict(results)

def main():
    print(f"{Colors.HEADER}{Colors.BOLD}PIR Sensor Test Utility{Colors.ENDC}")
    print("This utility will help you verify your PIR motion sensor connection.\n")
    
    setup_gpio()
    
    # First, test the default pin
    print(f"{Colors.CYAN}Testing the default pin (GPIO {DEFAULT_PIN})...{Colors.ENDC}")
    default_result = test_pin(DEFAULT_PIN, 10)
    
    if default_result > 0:
        print(f"\n{Colors.GREEN}{Colors.BOLD}Success!{Colors.ENDC} PIR sensor is working on GPIO {DEFAULT_PIN}.")
        print(f"Detected {default_result} movements during the test.")
        print("Your motion detection script is configured correctly.")
        return
    
    print(f"\n{Colors.YELLOW}No motion detected on the default GPIO {DEFAULT_PIN}.{Colors.ENDC}")
    scan_more = input("Would you like to scan all GPIO pins to find your PIR sensor? (Y/n): ")
    if scan_more.lower() == 'n':
        print("\nTest completed. Please check your PIR sensor connection and try again.")
        return
    
    # If default pin doesn't work, monitor all pins simultaneously
    results = monitor_all_pins_simultaneously()
    
    # Find pins with the most detections
    active_pins = {pin: count for pin, count in results.items() if count > 0}
    if active_pins:
        # Sort by detection count, highest first
        sorted_pins = sorted(active_pins.items(), key=lambda x: x[1], reverse=True)
        best_pin, best_count = sorted_pins[0]
        
        print(f"\n{Colors.GREEN}Results: Found potential PIR sensor connections!{Colors.ENDC}")
        for pin, count in sorted_pins:
            print(f"GPIO {pin}: {count} detections")
        
        print(f"\n{Colors.CYAN}Recommendation:{Colors.ENDC}")
        print(f"The most likely connection is GPIO {best_pin} with {best_count} detections.")
        
        # Updated recommendation text for manually changing the pin
        if best_pin != DEFAULT_PIN:
            print(f"\n{Colors.YELLOW}To use this pin instead of the default:{Colors.ENDC}")
            print(f"1. Open the motion_brightness.py file:")
            print(f"   sudo nano scripts/motion_brightness.py")
            print(f"2. Find this line (around line 74):")
            print(f"   PIR_PIN = {DEFAULT_PIN}")
            print(f"3. Change it to:")
            print(f"   PIR_PIN = {best_pin}")
            print(f"4. Save the file (Ctrl+O, then Enter, then Ctrl+X)")
        
        # Ask if they want to test the best pin more thoroughly
        test_more = input(f"Would you like to test GPIO {best_pin} for a longer duration to confirm? (Y/n): ")
        if test_more.lower() != 'n':
            print(f"\nTesting GPIO {best_pin} for 15 seconds...")
            confirmation = test_pin(best_pin, 15)
            if confirmation > 3:
                print(f"\n{Colors.GREEN}Confirmed!{Colors.ENDC} GPIO {best_pin} is receiving PIR sensor input.")
                if best_pin != DEFAULT_PIN:
                    print(f"Remember to update your motion_brightness.py file to use GPIO {best_pin} instead of {DEFAULT_PIN}.")
            else:
                print(f"\n{Colors.YELLOW}Inconclusive.{Colors.ENDC} Please check your connections and try again.")
    else:
        print(f"\n{Colors.RED}No motion detected on any GPIO pin.{Colors.ENDC}")
        print("Please check that:")
        print("1. The PIR sensor is properly powered (connected to 5V and GND)")
        print("2. The data/output pin of the sensor is connected to a GPIO pin")
        print("3. The sensor might have a warm-up or initialization period")

if __name__ == "__main__":
    # Check if running as root
    if os.geteuid() != 0:
        print(f"{Colors.RED}Error: This script must be run as root (sudo) to access GPIO pins.{Colors.ENDC}")
        print("Please run: sudo python3 pir_test.py")
        sys.exit(1)
        
    try:
        main()
        # Clean up
        GPIO.cleanup()
    except KeyboardInterrupt:
        print("\nTest interrupted by user.")
        GPIO.cleanup()
    except Exception as e:
        print(f"\n{Colors.RED}Error: {str(e)}{Colors.ENDC}")
        GPIO.cleanup() 