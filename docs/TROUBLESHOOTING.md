# Troubleshooting Guide

This guide covers common issues and solutions when using the WiFi Pineapple HCX Toolkit.

## Table of Contents
- [New Feature Issues (v8.0.0+)](#new-feature-issues-v800)
- [Capture Issues](#capture-issues)
- [Remote Execution](#remote-execution)
- [Interface & Hardware](#interface--hardware)
- [Script & Configuration](#script--configuration)

## New Feature Issues (v8.0.0+)

### Q: My `--random-mac`, `cloud-sync`, or dashboard map isn't working.
**A:** These advanced features depend on optional packages that must be installed separately.
-   **`--random-mac`** requires the `macchanger` package.
-   **`--utility cloud-sync`** requires the `rclone` package, which must also be configured by running `rclone config`.
-   The map in the **`--utility generate-dashboard`** report requires the `gpsbabel` package to process GPS data.

**Solution**: Please refer to `INSTALLATION.md` for instructions on how to install these recommended packages.

### Q: The `--mode trends` or `--utility find-reuse-targets` commands fail or show no data.
**A:** These intelligence modes operate entirely on the toolkit's historical database.
-   **Solution**: You must first populate the database by running captures and then processing them with the database mode:
    ```bash
    hcx-analyzer.sh --mode db /path/to/your/captures/
    ```
    The more data you log over time, the more insightful these reports will be.

### Q: The `--post-job` command doesn't seem to run after my capture.
**A:** This is usually an issue with how the arguments are quoted.
-   **Solution**: Ensure the arguments for the analyzer are wrapped in a single set of double quotes.
    ```bash
    # Correct:
    hcxdumptool-launcher.sh -d 300 --post-job "--mode recommend"

    # Incorrect (will fail):
    hcxdumptool-launcher.sh -d 300 --post-job --mode recommend
    ```

## Capture Issues

### Q: I ran `--optimize-performance`, but my capture rate didn't improve.
**A:** The `--optimize-performance` command only copies the configuration file into place; it does not automatically apply it. You **must** follow the manual steps displayed on-screen after running the command:
1.  **Edit the file**: Manually open `/etc/config/wireless` and set a new, secure password.
2.  **Commit the changes**: Run `uci commit wireless`.
3.  **Reboot**: Run `reboot`. The performance improvements only take effect after a full reboot.

### Q: My capture file is empty or no handshakes are found.
**A:** This is a common issue with several potential causes.
1.  **Performance Configuration**: If you have not yet run `--optimize-performance`, you are likely missing captures. This is the most common reason for poor results.
2.  **Use an Active Attack**: For best results, use an active attack mode like `--hunt-handshakes` or the new `--hunt-adaptive`. Passive listening (`--passive`) will only capture handshakes if a client happens to connect naturally.
3.  **Environment**: There may be no vulnerable handshakes or active clients nearby. Try moving to a busier location.

### Q: The script exits immediately with a "Killed" message.
**A:** This almost always means your device has run out of memory.
-   **Solution (Use Remote Analysis)**: The Pineapple's main limitation is memory/CPU. Offload analysis to a more powerful machine using the `--remote-mode` flags in `hcx-analyzer.sh`.

## Remote Execution

### Q: Remote execution fails with an SSH or SCP error.
**A:** This is almost always a configuration issue. The best way to solve this is to use the new setup wizard.
-   **Solution**: Run the automated remote setup wizard. It will diagnose and fix SSH key issues, check for dependencies, and save a correct configuration for you.
    ```bash
    hcx-analyzer.sh --utility setup-remote
    ```

## Interface & Hardware

### Q: The script complains about my interface mode. What should I do?
**A:** Nothing. The launcher is designed to handle this automatically. It will proactively set the interface to `managed` mode before starting a capture and will reliably restore it when finished.

### Q: My USB WiFi adapter is not found.
**A:** This is likely a driver issue.
1.  **Check Kernel Messages**: See if the OS recognized the adapter: `dmesg | tail`
2.  **Install Drivers**: You may need to install the correct kernel module (`kmod`) for your adapter's chipset.
3.  **Check Power**: The USB port may not be providing enough power. Try using a powered USB hub.

## Script & Configuration

### Q: My `--profile` is not being loaded.
**A:** The script looks for profile files in a specific location.
-   **Check Path**: Ensure your profile (e.g., `aggressive.conf`) is located at `/etc/hcxtools/profiles/aggressive.conf`.
-   **Check Name**: When using the flag, do not include the `.conf` extension. Use `--profile aggressive`, not `--profile aggressive.conf`.
