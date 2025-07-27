# Frequently Asked Questions (FAQ)

## Table of Contents
* [General Questions](#general-questions)
* [Installation & Usage](#installation--usage)
* [Technical Questions](#technical-questions)

## General Questions
### What is the WiFi Pineapple HCX Toolkit?
The HCX Toolkit is a powerful automation and intelligence framework for the `hcx` tool suite on the WiFi Pineapple. The v8.0.0 "Leviathan" release evolves it from a simple wrapper into a complete offensive and analysis platform, with features like a strategic recommendation engine, automated workflows, and advanced attack modes.

### What's the difference between this and the raw hcx tools?
This toolkit adds a user-friendly and feature-rich layer. Key advantages include:
* **Strategic Intelligence**: The toolkit analyzes your data and tells you what to do next (`--mode recommend`).
* **Full Automation**: Chain captures and analysis together (`--post-job`), get real-time cracking alerts (`--monitor` + Push Notifications), and sync to the cloud (`--utility cloud-sync`).
* **Advanced Attacks**: Use surgical, targeted deauthentication (`--hunt-adaptive`) and evade detection with MAC randomization (`--random-mac`).
* **Professional Reporting**: Generate a full HTML dashboard of all findings with one command (`--utility generate-dashboard`).
* **Simplified Setup**: A wizard (`--utility setup-remote`) automates the entire configuration of a remote analysis server.

## Installation & Usage
### Q: How do I use the new features like cloud sync or MAC randomization?
A: These features depend on optional packages. `cloud-sync` requires `rclone`, and `random-mac` requires `macchanger`. Please see the `INSTALLATION.md` file for simple, one-line installation commands for these packages.

### Q: How do I set up push notifications?
A: Open the main configuration file at `/etc/hcxtools/hcxscript.conf`. In it, you'll find a section for `Push Notification Settings`. Set `NOTIFICATION_ENABLED=1`, choose your service (`ntfy` or `discord`), and paste in your webhook URL.

### Q: Where are the files installed?
* **Main scripts**: `/usr/bin/hcxdumptool-launcher` and `/usr/bin/hcx-analyzer.sh`
* **Configuration & Data**: The entire `/etc/hcxtools/` directory.
* **Default Captures**: `/root/hcxdumps/`
* **Default Analysis Dir**: `/root/hcx-analysis/`
* **Local Database**: `/root/hcxdumps/database.db`
* **Wireless Backup**: `/etc/config/wireless.hcx-backup` (Created after running `--optimize-performance`)

## Technical Questions  
### Q: What is the difference between `--hunt-handshakes` and `--hunt-adaptive`?
A: They are two different levels of active deauthentication.
* `--hunt-handshakes` is a **broadcast** attack. It sends deauth frames to the entire network, forcing all connected clients to disconnect. It's noisy but effective.
* `--hunt-adaptive` is a **surgical** attack. It first scans to see which clients are actively talking, then sends deauth frames *only* to those specific clients. It is much stealthier and more efficient.

### Q: What is the Strategic Recommendation Engine?
A: The `--mode recommend` feature is an AI-like advisor. It runs a quick analysis on your captures to check key metrics (like the ratio of PMKIDs to full handshakes, or the presence of enterprise usernames). Based on these findings, it prints a prioritized list of suggested next steps to help you focus your efforts where they're most likely to succeed.
