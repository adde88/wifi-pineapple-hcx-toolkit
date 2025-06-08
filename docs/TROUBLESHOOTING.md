# Troubleshooting Guide

This guide covers common issues and solutions when using the WiFi Pineapple HCX Toolkit.

## Table of Contents
- [Capture Issues](#capture-issues)
- [Interface & Hardware](#interface--hardware)
- [Script & Configuration](#script--configuration)
- [Performance Problems](#performance-problems)

## Capture Issues

### Q: The script runs, but my capture file is empty or no handshakes are found.
**A:** This is a common issue with several potential causes.

1.  **Environment**: There may be no vulnerable handshakes or active clients nearby. Try moving to a busier location for testing.

2.  **Power Save**: Your WiFi card may be in power-saving mode, causing it to miss packets.
    -   **Solution**: Always use the `--disable-power-save` flag for active captures.

3.  **Wrong Channels**: You may be scanning channels with no activity.
    -   **Solution**: Use `--auto-channels` to let the script find active networks.

4.  **Distance**: You may be too far from the target. Physical proximity is key.

5.  **Attack Mode**: If you are only targeting APs (`-a ap`), you will not get EAPOL handshakes from clients.
    -   **Solution**: Use `-a all` for general-purpose capture.

### Q: The script says "Killed" and exits right after starting.
**A:** This almost always means your device has run out of memory.

-   **Solution 1 (Quiet Mode)**: The real-time display uses CPU and memory. Disable it with the `-q` (quiet) flag.
    ```bash
    hcxdumptool-launcher -q -d 300
    ```

-   **Solution 2 (Reduce Scope)**: Scan fewer channels instead of all of them.
    ```bash
    hcxdumptool-launcher -c 1,6,11
    ```

-   **Solution 3 (Stop Services)**: Stop other services on your Pineapple (`pineapd`, `lighttpd`) to free up RAM.

## Interface & Hardware

### Q: The script complains my interface is in "monitor mode".
**A:** `hcxdumptool` is designed to handle putting the card into monitor mode itself. You must start with the interface in `managed` mode.
-   **Solution**:
    ```bash
    iw wlan2 set type managed
    ```

### Q: My USB WiFi adapter is not found.
**A:** This is likely a driver issue.

1.  **Check Kernel Messages**: See if the OS recognized the adapter when you plugged it in.
    ```bash
    dmesg | tail
    ```
2.  **Install Drivers**: You may need to install the correct kernel module for your adapter's chipset. See the `INSTALLATION.md` guide for common driver packages on OpenWrt (`kmod-rtl8812au-ct`, etc.).
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

### Q: The `--run-and-crack` workflow ran, but no `.hc22000` file was created.
**A:** This is expected behavior if **no crackable handshakes** were captured. `hcxpcapngtool` will only create the output file if it successfully extracts at least one valid PMKID or EAPOL pair. The script will inform you that no hashes were found.

## Performance Problems

### Q: Captures seem slow or I'm missing packets.
**A:**
1.  **Disable Power Save**: This is the most common cause. Use `--disable-power-save`.
2.  **Stop Other Services**: Any other process using the CPU or writing to disk can slow down captures. Stop `pineapd` and other non-essential services.
3.  **Use External Storage**: The internal flash storage on the Pineapple can be slow. For long captures, consider mounting and using a fast USB drive for your output directory.
4.  **Limit Channels**: Don't scan all 80+ channels if your target is only on the 2.4GHz band. Use `-c 1,6,11` to focus the radio's time effectively.
