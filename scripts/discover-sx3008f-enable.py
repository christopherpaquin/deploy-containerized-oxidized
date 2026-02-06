#!/usr/bin/env python3
"""
SX3008F Enable Mode Command Discovery
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


def discover_enable_commands():
    """Discover commands in enable mode"""

    print("\n" + "=" * 60)
    print("SX3008F Enable Mode Command Discovery")
    print("=" * 60 + "\n")

    try:
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

        print("Connecting...")
        client.connect(
            DEVICE_IP,
            username=USERNAME,
            password=PASSWORD,
            timeout=TIMEOUT,
            look_for_keys=False,
            allow_agent=False,
        )

        shell = client.invoke_shell()
        time.sleep(2)

        # Clear buffer
        shell.recv(4096)

        # Enter enable mode
        print("Entering enable mode...")
        shell.send("enable\n")
        time.sleep(2)

        output = ""
        while shell.recv_ready():
            output += shell.recv(4096).decode("utf-8", errors="ignore")
        print(clean_output(output))

        # Now test show commands in enable mode
        print("\n" + "=" * 60)
        print("Testing commands in enable mode...")
        print("=" * 60)

        test_commands = [
            "?",
            "show ?",
            "display ?",
            "dir",
            "show version",
            "show running-config",
            "show startup-config",
            "show config",
            "show system",
            "show system-info",
            "display current-configuration",
            "display saved-configuration",
        ]

        for cmd in test_commands:
            print(f"\n--- Command: {cmd} ---")
            shell.send(cmd + "\n")
            time.sleep(2)

            output = ""
            while shell.recv_ready():
                output += shell.recv(4096).decode("utf-8", errors="ignore")
                time.sleep(0.1)

            cleaned = clean_output(output)
            lines = [line for line in cleaned.split("\n") if line.strip()]

            for line in lines[:40]:
                print(f"  {line}")

            if len(lines) > 40:
                print(f"  ... ({len(lines) - 40} more lines)")

        shell.send("exit\n")
        time.sleep(1)
        client.close()

        print("\nDone!")

    except Exception as e:
        print(f"\n[ERROR] {e}")
        import traceback

        traceback.print_exc()
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(discover_enable_commands())
