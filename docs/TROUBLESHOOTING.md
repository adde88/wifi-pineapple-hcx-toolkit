# Troubleshooting Guide

This guide covers common issues and solutions when using the WiFi Pineapple HCX Toolkit.

## Table of Contents
- [Capture Issues](#capture-issues)
- [Remote Execution](#remote-execution)
- [Interface & Hardware](#interface--hardware)
- [Script & Configuration](#script--configuration)

## Capture Issues

### Q: I ran `--optimize-performance`, but my capture rate didn't improve.
**A:** The `--optimize-performance` command only copies the configuration file into place; it does not automatically apply it. This is a safety measure. You **must** follow the manual steps displayed on-screen after running the command:
1.  **Edit the file**: Manually open `/etc/config/wireless` and set a new, secure password for the `MK7-ADMIN` network.
2.  **Commit the changes**: Run the command `uci commit wireless`.
3.  **Reboot**: Run the command `reboot`. The performance improvements will only take effect after a full reboot.

### Q: The script runs, but my capture file is empty or no handshakes are found.
**A:** This is a common issue with several potential causes.
1.  **Performance Configuration**: If you have not yet run `--optimize-performance`, you are likely missing a significant number of potential captures. This is the most common reason for poor results.
2.  **Environment**: There may be no vulnerable handshakes or active clients nearby. Try moving to a busier location for testing.
3.  **Wrong Channels**: You may be scanning channels with no activity. Try focusing on the most common channels, like `-c 1,6,11`.
4.  **Distance**: You may be too far from the target. Physical proximity is key for successful capture.

### Q: The script exits immediately with a "Killed" message.
**A:** This almost always means your device has run out of memory.
-   **Solution 1 (Reduce Scope)**: Scan fewer channels instead of all of them.
    ```bash
    hcxdumptool-launcher -i wlan2 -c 1,6,11
    ```
-   **Solution 2 (Use Remote Analysis)**: The Pineapple's main limitation is memory/CPU. Offload analysis to a more powerful machine using the `--remote-mode` flags in `hcx-analyzer.sh`. This is the recommended solution for memory issues.
-   **Solution 3 (Stop Services)**: Stop other services on your Pineapple (`pineapd`, `lighttpd`, etc.) to free up RAM.

### Q: The script complains about a missing backend like `hcxlabtool`.
**A:** The toolkit now supports multiple backend capture engines.
-   **Solution**: `hcxlabtool` is an optional, advanced backend. If you want to use it, you must install it via opkg: `opkg install hcxlabtool`. If you don't specify a backend, the script will default to the standard `hcxdumptool`, which is installed as a primary dependency.

## Remote Execution

### Q: Remote execution fails with an SSH or SCP error.
**A:** This is almost always a configuration issue.
1.  **Check Config**: Open `/etc/hcxtools/hcxscript.conf` and verify that `REMOTE_SERVER_HOST` and `REMOTE_SERVER_USER` are correct.
2.  **SSH Keys**: The script requires passwordless SSH key authentication to be set up between your Pineapple and the remote server. Ensure you can run `ssh user@host` from the Pineapple without being prompted for a password.
3.  **Remote Dependencies**: Ensure `hcxtools` is installed on the remote server and is in the user's PATH. You can verify this with `hcx-analyzer.sh --utility health_check`.

### Q: The analyzer script hangs or does nothing.
**A:**
- **Local Mode:** Analyzing large `.pcapng` files can take a very long time on the Pineapple's limited hardware. The script may appear to be hanging when it is actually processing. The spinner animation (`[|]`) is your indicator that work is being done.
- **Remote Mode:** When running a remote command, the spinner might pause during file uploads or SSH connections, which can be slow over WiFi. Use the `--verbose` (`-v`) flag for more insight into what's happening.

## Interface & Hardware

### Q: The script complains about my interface mode. What should I do?
**A:** Nothing. The launcher is designed to handle this automatically. It will proactively set the interface to `managed` mode before starting a capture and will reliably restore it when finished. This ensures the hardware is always in the correct state.

### Q: My USB WiFi adapter is not found.
**A:** This is likely a driver issue.
1.  **Check Kernel Messages**: See if the OS recognized the adapter when you plugged it in. `dmesg | tail`
2.  **Install Drivers**: You may need to install the correct kernel module (`kmod`) for your adapter's chipset.
3.  **Check Power**: The USB port may not be providing enough power for a high-gain adapter. Try using a powered USB hub.

## Script & Configuration

### Q: My `--profile` is not being loaded.
**A:** The script looks for profile files in a specific location.
-   **Check Path**: Ensure your profile (e.g., `aggressive.conf`) is located at `/etc/hcxtools/profiles/aggressive.conf`.
-   **Check Name**: When using the flag, do not include the `.conf` extension. Use `--profile aggressive`, not `--profile aggressive.conf`.