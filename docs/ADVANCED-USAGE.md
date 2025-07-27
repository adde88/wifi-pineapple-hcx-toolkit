# Advanced Usage Guide (v8.0.0 "Leviathan")

This guide covers advanced techniques and workflows for power users of the WiFi Pineapple HCX Toolkit.

## 1. Strategic Intelligence Engine
The "Leviathan" release introduces several modes that provide actionable intelligence, not just raw data. These modes require a populated database (`--mode db`).

* **`--mode recommend`**: The most powerful new feature. The script analyzes your captures and provides a prioritized list of suggested next steps.
    ```bash
    # Get strategic advice on how to proceed with your latest captures
    hcx-analyzer.sh --mode recommend /root/hcxdumps/
    ```
* **`--mode trends`**: Analyze how the wireless environment changes over time.
    ```bash
    # See what new devices have appeared and which have gone stale
    hcx-analyzer.sh --mode trends
    ```
* **`--utility find-reuse-targets`**: Scan for the critical vulnerability of password reuse.
    ```bash
    # Get a report of uncracked networks that may use a password you already know
    hcx-analyzer.sh --utility find-reuse-targets
    ```

## 2. Full-Spectrum Automation
Automate your entire workflow from capture to notification.

* **Chainable Job Queue (`--post-job`)**: Automatically run an analysis task after a capture finishes. This is the ultimate "fire-and-forget" feature.
    ```bash
    # Run a 10-minute tagged capture, then automatically generate an HTML dashboard for it
    hcxdumptool-launcher.sh -i wlan2 -d 600 --tag "CorpLobby" --post-job "--utility generate-dashboard"
    ```
* **Remote Crack Monitoring (`--monitor`)**: Get real-time feedback from a remote `hashcat` session.
    ```bash
    # Start a remote crack job and have the script automatically report new finds
    hcx-analyzer.sh --utility remote_crack --monitor all_hashes.hc22000
    ```
* **Push Notifications**: Configure `hcxscript.conf` with a `ntfy` or `Discord` webhook. The `--monitor` feature will then send push notifications to your phone or desktop the instant a password is cracked.

## 3. Advanced Offensive Suite
Execute more precise and evasive attacks.

* **Adaptive Deauthentication (`--hunt-adaptive`)**: A surgical attack that first performs reconnaissance to find active clients, then deauthenticates only those specific clients. It's more effective and stealthier than a broadcast attack.
    ```bash
    # Launch the interactive adaptive hunt wizard
    hcxdumptool-launcher.sh -i wlan2 --hunt-adaptive
    ```
* **MAC Address Randomization (`--random-mac`)**: Increase your anonymity during an engagement.
    ```bash
    # Run an adaptive hunt using a randomized MAC address
    hcxdumptool-launcher.sh -i wlan2 --hunt-adaptive --random-mac
    ```

## 4. Data Management (Tagging & Cloud Sync)
Organize your data and overcome the Pineapple's storage limitations.

* **Session Tagging (`--tag`)**: The core of data management. Apply a tag at capture time, then use the same tag during analysis to focus only on the relevant data.
    ```bash
    # Step 1: Capture data for a specific engagement
    hcxdumptool-launcher.sh -i wlan2 -d 300 --tag "Cafe-MainSt"
    
    # Step 2: Later, analyze only the data from that session
    hcx-analyzer.sh --mode summary --tag "Cafe-MainSt"
    ```
* **Cloud Sync (`--utility cloud-sync`)**: Use `rclone` to sync your captures and results with a cloud provider. This is essential for long-term data storage and offsite analysis.
    ```bash
    # After configuring rclone, upload new captures and download new results
    hcx-analyzer.sh --utility cloud-sync
    ```
