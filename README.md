# WiFi Pineapple HCX Toolkit 🍍
### v7.0.0 - "Hydra"

An advanced automation framework for `hcxdumptool`, `hcxlabtool`, and `hcxtools` on the WiFi Pineapple MKVII and other OpenWrt devices. This toolkit transforms the powerful `hcx` binaries into a streamlined, user-friendly, and highly effective system for WiFi security assessments.

---

## Core Philosophy

This toolkit was built to be a masterpiece of automation. It bridges the gap between the raw power of the HCX tools and the need for efficient, repeatable, and insightful analysis. It is designed for both novice users who need a guided experience and advanced users who require deep control and customization.

## Major Features (v7.0.0 "Hydra" Update)

This toolkit is more than just a wrapper; it's a complete workflow engine.

### **Remote Execution Engine: Offload to a Powerhouse**
* **Remote Analysis (`--remote-mode`)**: Offload intensive analysis tasks from the resource-constrained Pineapple to a powerful desktop PC. The script handles securely transferring files, executing the analysis remotely, and bringing the results back.
* **Remote Database (`--remote-mode mysql`)**: Log all findings directly to a remote MySQL/MariaDB server for centralized data management.
* **Remote Cracking (`--utility remote_crack`)**: Seamlessly send captured hashes to a remote machine with Hashcat for GPU-accelerated cracking.

### **Dual-Backend Attack System (--backend)**
Choose the right engine for the job:
* `hcxdumptool` **(Default)**: The classic, robust engine. Best for general-purpose, high-volume capture of handshakes and PMKIDs.
* `hcxlabtool` **(Advanced)**: A surgical tool for specialized attacks. Use this for stealthy client-only attacks (`--client-only-hunt`), focusing exclusively on PMKIDs (`--pmkid-priority-hunt`), or advanced techniques like the Time-Warp attack.

### **System Performance Optimization Engine**
* **`--optimize-performance`**: Applies a fine-tuned wireless configuration to the MKVII hardware, capable of boosting capture rates by over 450%.
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
* **hcxdumptool-custom**: v21.02.0 / 6.3.4 (specifically)
* **hcxtools-custom**: v6.2.7 (specifically)
* **hcxlabtool** (Optional, for advanced backend): v7.0 or newer.
* `git` and `opkg` for installation.
* root access.

### Support This Project
If you find this project helpful, please consider supporting its continued development:
- **Bitcoin**: `bc1qj85mvdr657nkzef4gppl9xy8eqerqga3suaqc3`

*Your support helps keep this project maintained and improved. Thank you!*
