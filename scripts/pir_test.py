#!/usr/bin/env python3
"""
PIR Sensor Test Utility

This script helps verify that a PIR motion sensor is properly connected
to the Raspberry Pi. It first tests the default pin (GPIO 24), and if
no motion is detected, it scans other available GPIO pins.

Usage: sudo python3 pir_test.py
"""

import RPi.GPIO as GPIO
import time
import sys
import argparse
import os

# Define color codes for terminal output
class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'

# Default pin for PIR sensor
DEFAULT_PIN = 24

# List of GPIO pins to test (excluding power and ground pins)
# These are BCM numbers, not physical pin numbers
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

def scan_all_pins(test_duration_per_pin=2):
    """
    Scan all available GPIO pins to find possible PIR connections
    Returns: Dictionary of pins and their motion detection counts
    """
    results = {}
    
    print(f"\n{Colors.CYAN}Scanning all available GPIO pins...{Colors.ENDC}")
    print(f"{Colors.YELLOW}Move around continuously to help detect the sensor.{Colors.ENDC}")
    print("This will take a while, please be patient.\n")
    
    for pin in AVAILABLE_PINS:
        try:
            count = test_pin(pin, test_duration_per_pin)
            results[pin] = count
            # If we got multiple detections, this is likely the pin
            if count >= 3:
                print(f"{Colors.GREEN}Found likely PIR sensor on GPIO {pin} with {count} detections!{Colors.ENDC}")
        except:
            # Skip pins that cause errors (might be in use by the system)
            print(f"Skipping GPIO {pin} (might be reserved or in use)")
            results[pin] = -1
    
    return results

def main():
    print(f"{Colors.HEADER}{Colors.BOLD}PIR Sensor Test Utility{Colors.ENDC}")
    print("This utility will help you verify your PIR motion sensor connection.\n")
    
    setup_gpio()
    
    # First test the default pin
    print(f"{Colors.CYAN}First, let's check the default pin (GPIO {DEFAULT_PIN})...{Colors.ENDC}")
    default_result = test_pin(DEFAULT_PIN, 10)
    
    if default_result > 0:
        print(f"\n{Colors.GREEN}{Colors.BOLD}Success!{Colors.ENDC} PIR sensor is working on GPIO {DEFAULT_PIN}.")
        print(f"Detected {default_result} movements during the test.")
        print("Your motion detection script is configured correctly.")
        sys.exit(0)
    
    print(f"\n{Colors.YELLOW}No motion detected on the default GPIO {DEFAULT_PIN}.{Colors.ENDC}")
    
    # Ask if user wants to scan all pins
    scan_all = input("Would you like to scan all available GPIO pins to find your PIR sensor? (y/N): ")
    if scan_all.lower() != 'y':
        print("\nTest completed. Please check your PIR sensor connection and try again.")
        sys.exit(1)
    
    # Scan all pins
    results = scan_all_pins()
    
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
        print(f"If you want to use this pin, you'll need to update the motion_brightness.py script.")
        print(f"The pin is currently set to GPIO {DEFAULT_PIN}.")
        
        # Ask if they want to test the best pin more thoroughly
        test_more = input(f"Would you like to test GPIO {best_pin} for a longer duration to confirm? (Y/n): ")
        if test_more.lower() != 'n':
            print(f"\nTesting GPIO {best_pin} for 15 seconds...")
            confirmation = test_pin(best_pin, 15)
            if confirmation > 3:
                print(f"\n{Colors.GREEN}Confirmed!{Colors.ENDC} GPIO {best_pin} is receiving PIR sensor input.")
                print("You should reconfigure your motion detection script to use this pin.")
            else:
                print(f"\n{Colors.YELLOW}Inconclusive.{Colors.ENDC} Please check your connections and try again.")
    else:
        print(f"\n{Colors.RED}No motion detected on any GPIO pin.{Colors.ENDC}")
        print("Please check that:")
        print("1. The PIR sensor is properly powered (connected to 5V and GND)")
        print("2. The data/output pin of the sensor is connected to a GPIO pin")
        print("3. The sensor might have a warm-up or initialization period")
    
    # Clean up
    GPIO.cleanup()

if __name__ == "__main__":
    # Check if running as root
    if os.geteuid() != 0:
        print(f"{Colors.RED}Error: This script must be run as root (sudo) to access GPIO pins.{Colors.ENDC}")
        print("Please run: sudo python3 pir_test.py")
        sys.exit(1)
        
    try:
        main()
    except KeyboardInterrupt:
        print("\nTest interrupted by user.")
        GPIO.cleanup()
    except Exception as e:
        print(f"\n{Colors.RED}Error: {str(e)}{Colors.ENDC}")
        GPIO.cleanup() 