#!/usr/bin/env python3
"""
TP-Link Command Discovery Script
Tests various commands to determine what this TP-Link switch supports
"""

import telnetlib
import time
import sys

# Configuration
DEVICE_IP = sys.argv[1] if len(sys.argv) > 1 else "10.1.10.48"
USERNAME = sys.argv[2] if len(sys.argv) > 2 else "admin"
PASSWORD = sys.argv[3] if len(sys.argv) > 3 else "thunder123"
TIMEOUT = 10

# ANSI colors
RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
BLUE = "\033[0;34m"
RESET = "\033[0m"


def test_commands():
    """Connect to TP-Link and test commands"""

    print(f"\n{BLUE}========================================{RESET}")
    print(f"{BLUE}TP-Link Command Discovery{RESET}")
    print(f"{BLUE}========================================{RESET}\n")
    print(f"Device: {DEVICE_IP}")
    print(f"User:   {USERNAME}\n")

    try:
        # Connect
        print(f"{BLUE}Connecting via telnet...{RESET}")
        tn = telnetlib.Telnet(DEVICE_IP, 23, TIMEOUT)

        # Login
        print(f"{BLUE}Logging in...{RESET}")
        tn.read_until(b"User:", timeout=5)
        tn.write(USERNAME.encode("ascii") + b"\n")

        tn.read_until(b"Password:", timeout=5)
        tn.write(PASSWORD.encode("ascii") + b"\n")

        # Wait for prompt
        time.sleep(2)
        output = tn.read_very_eager().decode("ascii", errors="ignore")
        print(output)

        if "Login invalid" in output:
            print(f"{RED}✗ Login failed{RESET}")
            return

        print(f"{GREEN}✓ Logged in successfully{RESET}\n")

        # Test commands
        commands = [
            "?",
            "show ?",
            "help",
            "show system-info",
            "show running-config",
            "show run",
            "show config",
            "display current-configuration",
        ]

        for cmd in commands:
            print(f"\n{BLUE}--- Testing: {cmd} ---{RESET}")
            tn.write(cmd.encode("ascii") + b"\n")
            time.sleep(2)

            output = tn.read_very_eager().decode("ascii", errors="ignore")

            # Clean up output
            lines = [line for line in output.split("\n") if line.strip()]

            if any(
                err in output
                for err in ["Error", "Invalid", "Bad command", "Unrecognized"]
            ):
                print(f"{RED}✗ Command failed{RESET}")
            elif len(lines) > 2:
                print(f"{GREEN}✓ Command produced output:{RESET}")
                for line in lines[:20]:  # Show first 20 lines
                    print(f"  {line}")
            else:
                print(f"{YELLOW}? Unclear result{RESET}")
                print(output)

        # Exit
        print(f"\n{BLUE}Exiting...{RESET}")
        tn.write(b"exit\n")
        tn.close()

    except Exception as e:
        print(f"{RED}ERROR: {e}{RESET}")
        return 1

    print(f"\n{GREEN}========================================{RESET}")
    print(f"{GREEN}Test complete{RESET}")
    print(f"{GREEN}========================================{RESET}\n")
    return 0


if __name__ == "__main__":
    sys.exit(test_commands())
