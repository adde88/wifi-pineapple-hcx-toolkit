# Advanced Usage Guide

This guide covers advanced techniques and scenarios for power users of the WiFi Pineapple HCX Toolkit.

## 1. Workflow Automation

The launcher includes several flags to automate common workflows from a single command.

### Client Hunting (`--client-hunt`)
This mode automatically optimizes the settings for capturing client probe requests and handshakes. It's the fastest way to find what clients are in the area.
```bash
# Run a client hunt for 10 minutes, then convert the results for cracking
hcxdumptool-launcher --client-hunt -d 600 --run-and-crack

Wardriving (--wardriving-loop)
This mode is perfect for mobile data collection. It runs captures in a continuous loop, saving a new timestamped file for each cycle.

# Start a wardriving session, saving a new file every 5 minutes (300s)
# Enable GPS logging for geographic correlation if a GPS dongle is connected
hcxdumptool-launcher --wardriving-loop 300 -g

Automatic Cracking Prep (--run-and-crack)
After any capture, this flag will automatically run hcxpcapngtool to convert the results into a hashcat-compatible format.

# Run a standard capture for 15 minutes, then convert
hcxdumptool-launcher -d 900 --run-and-crack

# Convert to a specific hashcat format (e.g., WPA-PMKID-PBKDF2)
hcxdumptool-launcher -d 900 --run-and-crack --export-format 16800

2. Using Configuration Profiles (--profile)
Profiles allow you to save and load complete sets of arguments for repeatable scenarios. Profiles are stored as .conf files in /etc/hcxtools/profiles/.

Example aggressive.conf profile:

# /etc/hcxtools/profiles/aggressive.conf
#
# Profile for active, aggressive capture.

ATTACK_MODE="all"
POWER_SAVE_DISABLE=1
AUTO_CHANNELS=1
RDS_MODE=2

To use the profile:

# First, see what profiles are available
hcxdumptool-launcher --list-profiles

# Load the 'aggressive' profile and run for 10 minutes
hcxdumptool-launcher --profile aggressive -d 600

Flags passed on the command line will always override settings from a profile.

3. Custom BPF Filters
Use Berkeley Packet Filters to capture only the specific traffic you are interested in.

Creating a WPA3-Only Filter
# This tcpdump command creates a BPF file that targets WPA3 management frames
# Note: You must have tcpdump installed to create new filters.
tcpdump -ddd 'wlan type mgt subtype beacon and wlan[40] & 0x10 = 0x10' \
    > /etc/hcxtools/bpf-filters/wpa3-sae-only.bpf

Using a Custom Filter
# See what filters are already installed
hcxdumptool-launcher --list-filters

# Run a capture using the new WPA3 filter
hcxdumptool-launcher -b /etc/hcxtools/bpf-filters/wpa3-sae-only.bpf

4. Automation with Cron
The launcher is ideal for scheduled, automated captures. Use crontab -e to edit your schedule.

# Every day at 2 AM, run a 4-hour capture of guest networks
# This uses a profile that might whitelist the guest network's MAC address
0 2 * * * /usr/bin/hcxdumptool-launcher --profile guest-audit -d 14400 -q

# Every 15 minutes, run a quick 1-minute scan for new clients
*/15 * * * * /usr/bin/hcxdumptool-launcher --client-hunt -d 60 -q

5. Debugging with Dry Run
Before launching a complex command, you can use --dry-run to see the exact command that would be executed. This is perfect for verifying your profiles and flags.

# See what command the 'stealth' profile and a BPF filter would generate
hcxdumptool-launcher --profile stealth -b /etc/hcxtools/bpf-filters/no-beacons.bpf --dry-run
