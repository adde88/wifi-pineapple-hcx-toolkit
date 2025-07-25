# Troubleshooting Guide

This guide covers common issues and solutions when using the WiFi Pineapple HCX Toolkit.

## Table of Contents
- [Capture Issues](#capture-issues)
- [Interface & Hardware](#interface--hardware)
- [Script & Configuration](#script--configuration)

## Capture Issues

### Q: The script runs, but my capture file is empty or no handshakes are found.
**A:** This is a common issue with several potential causes.

1.  **Environment**: There may be no vulnerable handshakes or active clients nearby. Try moving to a busier location for testing.
2.  **Wrong Channels**: You may be scanning channels with no activity. Try focusing on the most common channels, like `-c 1,6,11`.
3.  **Distance**: You may be too far from the target. Physical proximity is key for successful capture.

### Q: The script exits immediately with a "Killed" message.
**A:** This almost always means your device has run out of memory.
-   **Solution 1 (Reduce Scope)**: Scan fewer channels instead of all of them.
    ```bash
    hcxdumptool-launcher -i wlan2 -c 1,6,11
    ```
-   **Solution 2 (Stop Services)**: Stop other services on your Pineapple (`pineapd`, `lighttpd`, etc.) to free up RAM.

## Interface & Hardware

### Q: The script complains about my interface mode. What should I do?
**A:** Nothing. The v5.0.0 launcher is designed to handle this automatically. It will proactively set the interface to `managed` mode before starting a capture and will reliably restore it to `managed` mode when finished. This ensures the hardware is always in the correct state.

### Q: My USB WiFi adapter is not found.
**A:** This is likely a driver issue.

1.  **Check Kernel Messages**: See if the OS recognized the adapter when you plugged it in.
    ```bash
    dmesg | tail
    ```
2.  **Install Drivers**: You may need to install the correct kernel module (`kmod`) for your adapter's chipset.
3.  **Check Power**: The USB port may not be providing enough power for a high-gain adapter. Try using a powered USB hub.

## Script & Configuration

### Q: My `--profile` is not being loaded.
**A:** The script looks for profile files in a specific location.
-   **Check Path**: Ensure your profile (e.g., `aggressive.conf`) is located at `/etc/hcxtools/profiles/aggressive.conf`.
-   **Check Name**: When using the flag, do not include the `.conf` extension. Use `--profile aggressive`, not `--profile aggressive.conf`.
-   **Re-install**: The easiest way to fix pathing issues is to re-run the installer from the git-cloned directory: `./hcxdumptool-launcher.sh --install`

### Q: I get a "command not found" error when running `hcxdumptool-launcher`.
**A:** This means the script was not installed into your system's PATH.
-   **Solution**: You must run the `--install` command first. This copies the script to `/usr/bin/`, which is in your PATH. If you have not installed it, you must run it from its current directory with `./hcxdumptool-launcher.sh`.

### Q: The analyzer script hangs or does nothing.
**A:**
- **Solution 1 (Patience):** Analyzing large `.pcapng` files can take a very long time on the Pineapple's limited hardware. The script may appear to be hanging when it is actually processing. The spinner animation (`[|]`) is your indicator that work is being done in the background.
- **Solution 2 (Verbose Mode):** Run the analyzer with the `--verbose` flag to see the raw output from the tools, which can help identify a specific command that is failing.
  ```bash
  hcx-analyzer.sh --verbose