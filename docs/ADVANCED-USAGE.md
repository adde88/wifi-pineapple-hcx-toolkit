# Advanced Usage Guide (v5.0.0+)
This guide covers advanced techniques for power users of the WiFi Pineapple HCX Toolkit. All examples from v4 remain valid, with new features and aliases added for v5.0.0.

## 1. Workflow Automation
The launcher includes flags to automate common workflows from a single command.

### Client Hunting (--client-hunt)
This mode optimizes settings for capturing client probe requests and handshakes.

```bash
# Run a client hunt for 10 minutes, then prepare the results for cracking
hcxdumptool-launcher --client-hunt -d 600 --auto-convert
```
Note: --run-and-crack from v4 is still a valid alias for --auto-convert.

###Wardriving (--wardriving-loop)
This mode is for mobile data collection, running captures in a continuous loop. GPS logging via the -g flag is more robust in v5.0.0.
```bash
# Start a wardriving session, saving a new file every 5 minutes (300s)
# -g enables more reliable GPS logging if a dongle is connected
hcxdumptool-launcher --wardriving-loop 300 -g
```
Automatic Post-Capture Processing
After a capture, you can automatically analyze or convert the data.

New in v5.0.0: Instant Analysis (--pcap-analyze)
This powerful new flag provides an immediate summary of the contents of your capture file, showing networks, clients, handshakes, and more without needing external tools.

```bash
# Run a standard capture for 5 minutes, then analyze the results
hcxdumptool-launcher -d 300 --pcap-analyze
```
Conversion for Cracking (--auto-convert)
This flag automatically runs hcxpcapngtool to convert results into a hashcat-compatible format. This is the new, preferred name for --run-and-crack.

```bash
# Run a standard capture for 15 minutes, then convert
hcxdumptool-launcher -d 900 --auto-convert
```
# The --export-format flag is still functional but deprecated.
# For specific formats, manual conversion with hcxpcapngtool is now recommended.
hcxdumptool-launcher -d 900 --auto-convert --export-format 16800
2. Using Configuration Profiles (--profile)
Profiles allow you to save and load complete sets of arguments. In v5.0.0, you can add a DESCRIPTION to your profiles for clarity.

Example aggressive.conf profile:

```bash
# /etc/hcxtools/profiles/aggressive.conf
#
# Profile for active, aggressive capture.

DESCRIPTION="Active capture using all attack modes and high RDS refresh."
ATTACK_MODE="all"
POWER_SAVE_DISABLE=1
AUTO_CHANNELS=1
RDS_MODE=2
Using the profile:
```

```bash
# See what profiles are available (now includes descriptions)
hcxdumptool-launcher --list-profiles

# Load the 'aggressive' profile and run for 10 minutes
hcxdumptool-launcher --profile aggressive -d 600
```
Flags passed on the command line will always override settings from a profile.

3. Using BPF Filters
Use Berkeley Packet Filters to capture only specific traffic. The toolkit now ships with several pre-made filters.

Using a Built-in Filter
You no longer need to create a WPA3 filter manually; it's included in v5.0.0.

Bash

# See what pre-installed filters are available
hcxdumptool-launcher --list-filters

# Run a capture using the built-in WPA3 filter
hcxdumptool-launcher -b /etc/hcxtools/bpf-filters/wpa3-sae-only.bpf
Creating a Custom Filter
You can still create your own filters using tcpdump for specialized needs.

Bash

# Example: Create a filter for only MFP (802.11w) enabled networks
tcpdump -ddd 'wlan type mgt subtype beacon and wlan[52] & 0xc0 = 0x80' \
    > /etc/hcxtools/bpf-filters/mfp-required.bpf
4. Automation with Cron
The launcher is ideal for scheduled, automated captures. These examples remain fully valid.

Bash

# Every day at 2 AM, run a 4-hour capture of guest networks
0 2 * * * /usr/bin/hcxdumptool-launcher --profile guest-audit -d 14400 -q

# Every 15 minutes, run a quick 1-minute scan for new clients
*/15 * * * * /usr/bin/hcxdumptool-launcher --client-hunt -d 60 -q
5. Debugging with Dry Run
Before launching a complex command, use --dry-run to see the exact hcxdumptool command that would be executed. This is perfect for verifying your profiles and flags.

Bash

# See what command the 'stealth' profile and a BPF filter would generate
hcxdumptool-launcher --profile stealth -b /etc/hcxtools/bpf-filters/no-beacons.bpf --dry-run