# WiFi Pineapple HCX Toolkit 🍍
### v5.0.0 - "The Masterpiece Edition"

An advanced automation framework for `hcxdumptool` and `hcxtools` on the WiFi Pineapple MKVII and other OpenWrt devices. This toolkit transforms the powerful `hcx` binaries into a streamlined, user-friendly, and highly effective system for WiFi security assessments.

---

## Core Philosophy

This toolkit was built to be a masterpiece of automation. It bridges the gap between the raw power of `hcxdumptool` and the need for efficient, repeatable, and insightful analysis. It is designed for both novice users who need a guided experience and advanced users who require deep control and customization.

## Major Features

This toolkit is more than just a wrapper; it's a complete workflow engine.

### **Easy Modes: "Personas" for Every Scenario**
Get started immediately with simple, powerful flags for common tasks:
* `--hunt-handshakes`: The go-to mode for actively capturing WPA/WPA2 handshakes via deauthentication attacks.
* `--passive`: A 100% stealthy listening mode that disables all outgoing packets. Perfect for covert monitoring.
* `--survey`: A quick, non-intrusive scan to see all APs in the area without attacking or saving files.
* `--enable-gps`: Automatically use a connected `gpsd`-compatible device to embed coordinates directly into capture files.

### **The HCX Analyzer: Beyond Just Hashes**
The completely overhauled `hcx-analyzer.sh` script is the heart of the toolkit, offering multiple analysis modes through an **interactive menu**:
* **`--mode summary`**: Get a quick or deep overview of captured hashes, network names, and devices.
* **`--mode intel`**: A powerful, automated intelligence gathering mode to report on device vendors, group hashes by ESSID, and get detailed statistics.
* **`--mode vuln`**: A comprehensive vulnerability assessment that tests for thousands of known default router passwords and identifies other weaknesses.
* **`--mode export`**: Converts your captures and data into other common formats like `.cap` and `.csv` for use in other tools or for reporting.
* **`--mode remote-crack`**: Securely offloads your captured hashes to a more powerful machine for cracking with `hashcat`, configured via `/etc/hcxtools/hcxscript.conf`.

### **Workflow & Customization**
Tailor the toolkit to your exact needs:
* `--wardriving-loop <seconds>`: Run captures in continuous, timed loops for mobile data collection.
* `--profile <name>`: Load pre-defined sets of arguments from configuration files for specific, repeatable scenarios.

### **System & Reliability**
Built for stability and ease of management on embedded devices:
* **Robust Dependency Checking**: Uses a fast and reliable method to ensure correct tool versions are installed.
* **Reliable Interface Management**: Proactively sets the wireless interface to managed mode and correctly restores it upon completion.
* **Automatic Updates**: The `--update` flag checks the GitHub repository for the latest version and installs it.

---

## Requirements
* A WiFi Pineapple MKVII or other OpenWrt-based device.
* `hcxdumptool-custom` (v6.3.4-2 or newer)
* `hcxtools-custom` (v6.2.7-1 or newer)
* `git` and `opkg` for installation.
* Root access.


### Support This Project
If you find this project helpful, please consider supporting its continued development:  
- **Bitcoin**: Scan the QR code below or use this BTC address:  
  **`bc1qj85mvdr657nkzef4gppl9xy8eqerqga3suaqc3`**
  
  ![BTC Donation QR Code](assets/qr-btc-address-200.png)

- **Contribute**: Pull requests and bug reports are always welcome!

*Your support helps keep this project maintained and improved. Thank you! ??*
