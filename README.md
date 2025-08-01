# WiFi Pineapple HCX Toolkit 🍍
### v8.0.7 - "Leviathan"

An advanced automation framework for `hcxdumptool`, and `hcxtools` on the WiFi Pineapple MKVII and other OpenWrt devices. This toolkit transforms the powerful `hcx` binaries into a streamlined, user-friendly, and highly effective system for WiFi security assessments.

---

## ⚠️ Important Installation Notice

The toolkit includes a `wireless.config` file designed for high-performance capture. **You MUST edit this file** with your own admin network name (SSID) and password before running the `--optimize-performance` command.

Failure to edit this file first will result in you being **locked out** of your admin network.

---

## Core Philosophy

This toolkit was built to be a masterpiece of automation. It bridges the gap between the raw power of the HCX tools and the need for efficient, repeatable, and insightful analysis. It is designed for both novice users who need a guided experience and advanced users who require deep control and customization.

## Major Features

This toolkit is more than just a wrapper; it's a complete workflow engine.

### **System Performance Optimization Engine**
* **`--optimize-performance`**: Applies the fine-tuned `wireless.config` file to the MKVII hardware, capable of boosting capture rates. **Remember to edit the file with your credentials first!**
* **`--restore-config`**: Instantly reverts to your original, backed-up wireless configuration.

### **The HCX Analyzer: Beyond Just Hashes**
The completely overhauled `hcx-analyzer.sh` script is the heart of the toolkit, offering multiple analysis modes through an **interactive menu**:
* **`--mode summary`**: Get a quick or deep overview of captured hashes, network names, and devices.
* **`--mode intel`**: A powerful, automated intelligence gathering mode to report on device vendors and group hashes.
* **`--mode vuln`**: A comprehensive vulnerability assessment that tests for thousands of known default router passwords.
* **`--mode pii`**: Scans captures for Personally Identifiable Information (PII) like usernames and identities from enterprise networks.
* **`--mode db`**: Logs all findings to a local SQLite database for persistent storage and querying.
* **`--utility geotrack`**: Creates a KML map file from captures that contain GPS data.
* **`--utility export`**: Converts your captures into other common formats like `.cap` and `.csv`.

### **Advanced Filtering**
* **Capture-Time Filtering**: Use `--filter-file` or `--oui-file` to whitelist or blacklist devices by full MAC address or vendor OUI before the capture even starts.
* **Post-Capture Filtering**: The analyzer's `--utility filter_hashes` can filter a hash file by dozens of criteria, including ESSID length/regex, hash type, handshake authorization state, and more.

### **Workflow & Customization**
* `--wardriving-loop <seconds>`: Run captures in continuous, timed loops for mobile data collection.
* `--profile <name>`: Load pre-defined sets of arguments from configuration files for specific, repeatable scenarios.
* `--enable-gps`: Automatically use a connected `gpsd`-compatible device to embed coordinates directly into capture files.

---

## Requirements
* A WiFi Pineapple MKVII or other OpenWrt-based device.
* **hcxdumptool-custom**: v21.02.0 / 6.3.5
* **hcxtools-custom**: v6.2.7
* `git` and `opkg` for installation.
* root access.

### Support This Project
If you find this project helpful, please consider supporting its continued development:
- **Bitcoin**: `bc1qj85mvdr657nkzef4gppl9xy8eqerqga3suaqc3`

*Your support helps keep this project maintained and improved. Thank you!*
