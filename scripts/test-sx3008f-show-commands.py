#!/usr/bin/env python3
"""
Test specific show commands on SX3008F with proper waiting
"""

import paramiko
import time
import sys

DEVICE_IP = "10.1.10.48"
USERNAME = "admin"
PASSWORD = "thunder123"


def wait_for_prompt(shell, timeout=5):
    """Wait for prompt and return output"""
    output = ""
    start = time.time()
    while time.time() - start < timeout:
        if shell.recv_ready():
            chunk = shell.recv(4096).decode("utf-8", errors="ignore")
            output += chunk
            # Check if we got a prompt
            if ">" in output or "#" in output:
                time.sleep(0.5)  # Give it a moment for any remaining output
                while shell.recv_ready():
                    output += shell.recv(4096).decode("utf-8", errors="ignore")
                break
        time.sleep(0.1)
    return output


def test_show_commands():
    """Test show commands properly"""

    print("\n" + "=" * 70)
    print("SX3008F Show Command Testing")
    print("=" * 70 + "\n")

    try:
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

        print("Connecting...")
        client.connect(
            DEVICE_IP,
            username=USERNAME,
            password=PASSWORD,
            timeout=10,
            look_for_keys=False,
            allow_agent=False,
        )

        shell = client.invoke_shell(width=200, height=100)
        time.sleep(2)

        # Clear buffer
        wait_for_prompt(shell)

        # Enter enable mode
        print("Entering enable mode...")
        shell.send("enable\n")
        output = wait_for_prompt(shell)
        print(output)

        # Test commands one by one
        test_commands = [
            ("show version", "System/hardware information"),
            ("show running-config", "Current running configuration"),
            ("show startup-config", "Saved startup configuration"),
            ("show config", "Configuration (alternative)"),
            ("show system", "System information"),
            ("show system-info", "System info (alternative)"),
            ("display current-configuration", "Huawei-style current config"),
            ("dir", "Directory listing"),
            ("show interface", "Interface information"),
            ("show vlan", "VLAN configuration"),
            ("show port", "Port information"),
        ]

        results = []

        for cmd, description in test_commands:
            print(f"\n{'='*70}")
            print(f"Testing: {cmd}")
            print(f"Purpose: {description}")
            print("=" * 70)

            shell.send(cmd + "\n")
            output = wait_for_prompt(shell, timeout=10)

            # Clean output
            lines = [
                line.strip()
                for line in output.split("\n")
                if line.strip() and line.strip() != cmd
            ]

            # Check if command worked
            if "Error" in output or "Bad command" in output or "Invalid" in output:
                print("❌ Command failed")
                results.append((cmd, False, "ERROR"))
            elif len(lines) < 3:
                print("⚠️  No significant output")
                results.append((cmd, False, "NO_OUTPUT"))
                for line in lines:
                    print(f"  {line}")
            else:
                print("✅ Command produced output!")
                results.append((cmd, True, "SUCCESS"))
                # Show first 20 lines
                for line in lines[:20]:
                    print(f"  {line}")
                if len(lines) > 20:
                    print(f"  ... ({len(lines) - 20} more lines)")

        shell.send("exit\n")
        time.sleep(1)
        client.close()

        # Summary
        print("\n" + "=" * 70)
        print("SUMMARY")
        print("=" * 70)

        working_commands = [cmd for cmd, success, _ in results if success]

        if working_commands:
            print("\n✅ Working commands:")
            for cmd in working_commands:
                print(f"  - {cmd}")
        else:
            print("\n❌ No working commands found")

        print("\n")

    except Exception as e:
        print(f"\n[ERROR] {e}")
        import traceback

        traceback.print_exc()
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(test_show_commands())
