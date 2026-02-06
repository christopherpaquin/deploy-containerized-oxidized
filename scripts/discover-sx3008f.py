#!/usr/bin/env python3
"""
SX3008F CLI Command Discovery
Uses paramiko to discover available CLI commands
"""

import paramiko
import time
import sys
import re

DEVICE_IP = "10.1.10.48"
USERNAME = "admin"
PASSWORD = "thunder123"
TIMEOUT = 5


def clean_output(text):
    """Remove ANSI escape codes and clean up output"""
    ansi_escape = re.compile(r"\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])")
    text = ansi_escape.sub("", text)
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    return text


def discover_commands():
    """Connect and discover commands"""

    print("\n" + "=" * 60)
    print("SX3008F CLI Command Discovery")
    print("=" * 60 + "\n")
    print(f"Device: {DEVICE_IP}")
    print(f"User:   {USERNAME}\n")

    try:
        # Create SSH client
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

        print("Connecting via SSH...")
        client.connect(
            DEVICE_IP,
            username=USERNAME,
            password=PASSWORD,
            timeout=TIMEOUT,
            look_for_keys=False,
            allow_agent=False,
        )

        # Open interactive shell
        print("Opening interactive shell...")
        shell = client.invoke_shell()
        time.sleep(2)

        # Clear initial output
        initial = shell.recv(4096).decode("utf-8", errors="ignore")
        print("\nInitial prompt:")
        print(clean_output(initial))

        # Test commands
        test_commands = [
            "?",
            "help",
            "show ?",
            "enable",
            "?",  # After enable
            "show ?",  # After enable
            "configure",
            "?",  # In config mode
            "exit",
            "show",
            "display",
            "get",
            "list",
            "dir",
            "ls",
        ]

        results = {}

        for cmd in test_commands:
            print(f"\n{'='*60}")
            print(f"Testing command: '{cmd}'")
            print("=" * 60)

            # Send command
            shell.send(cmd + "\n")
            time.sleep(2)

            # Receive output
            output = ""
            while shell.recv_ready():
                chunk = shell.recv(4096).decode("utf-8", errors="ignore")
                output += chunk
                time.sleep(0.1)

            cleaned = clean_output(output)
            results[cmd] = cleaned

            # Print output
            lines = cleaned.split("\n")
            for line in lines[:30]:  # Show first 30 lines
                if line.strip():
                    print(f"  {line}")

            if len(lines) > 30:
                print(f"  ... ({len(lines) - 30} more lines)")

        # Cleanup
        shell.send("exit\n")
        time.sleep(1)
        client.close()

        # Save full results
        print("\n" + "=" * 60)
        print("Saving full results...")
        print("=" * 60)

        with open("/tmp/sx3008f-full-discovery.log", "w") as f:
            for cmd, output in results.items():
                f.write(f"\n{'='*60}\n")
                f.write(f"Command: {cmd}\n")
                f.write(f"{'='*60}\n")
                f.write(output)
                f.write("\n")

        print("\nFull log saved to: /tmp/sx3008f-full-discovery.log")
        print("\nDone!")

    except paramiko.AuthenticationException:
        print("\n[ERROR] Authentication failed")
        return 1
    except paramiko.SSHException as e:
        print(f"\n[ERROR] SSH error: {e}")
        return 1
    except Exception as e:
        print(f"\n[ERROR] {e}")
        import traceback

        traceback.print_exc()
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(discover_commands())
