# WiFi Pineapple HCX Toolkit 🍍
### v8.0.0 - "Leviathan"

An advanced offensive and intelligence framework for `hcxdumptool`, `hcxlabtool`, and `hcxtools` on the WiFi Pineapple MKVII and other OpenWrt devices. This toolkit transforms the powerful `hcx` binaries into an automated, intelligent, and highly effective system for WiFi security assessments.

---

## Core Philosophy

This toolkit was built to be a masterpiece of automation. It bridges the gap between the raw power of the HCX tools and the need for efficient, repeatable, and insightful analysis. The "Leviathan" release evolves this philosophy, turning the toolkit into a proactive decision-support system that not only gathers data but tells you how to use it.

## Major Features (v8.0.0 "Leviathan" Update)

This toolkit is more than just a wrapper; it's a complete operational framework.

### 🧠 **Strategic Intelligence Engine**
The toolkit no longer just shows you data; it provides actionable intelligence.
* **`--mode recommend`**: Acts as a virtual strategist, analyzing captures to suggest the most effective, high-probability attack vectors to pursue next.
* **`--mode trends`**: Performs historical analysis on your database to report on long-term environmental changes, new devices, and assets that have gone dark.
* **`--utility find-reuse-targets`**: Automatically cross-references cracked passwords against all uncracked networks with the same name, identifying critical credential reuse vulnerabilities.

### ⚙️ **Full-Spectrum Automation**
Execute complex workflows with a single command and receive results autonomously.
* **`--post-job`**: A "fire-and-forget" chainable job queue. Automatically run any analysis command (like generating a dashboard) the moment a capture is complete.
* **`--monitor`**: When cracking remotely, this flag turns the analyzer into a monitoring station that automatically fetches and displays newly cracked passwords as they are found.
* **Push Notifications**: The analyzer can be configured to send C2-style callbacks via `ntfy` or `Discord` the instant a password is cracked, reporting its victories to you.

### ⚔️ **Advanced Offensive Suite**
Execute more precise, effective, and evasive attacks.
* **`--hunt-adaptive`**: A surgical attack mode that performs reconnaissance to identify and target only active clients, maximizing handshake capture success while minimizing network noise.
* **`--random-mac`**: Evade detection by randomizing the capture interface's MAC address before going active, automatically restoring it upon completion.
* **Dual-Backend System (`--backend`)**: Seamlessly switch between the robust, high-volume capture of `hcxdumptool` and the specialized, surgical attacks of `hcxlabtool`.

### 📊 **Situational Awareness & Reporting**
Visualize the battlefield and generate professional reports with a single command.
* **`--utility generate-dashboard`**: Fuses all collected intelligence—cracked credentials, network lists, PII, and GPS tracks—into a single, self-contained HTML dashboard perfect for briefings.
* **`--utility geotrack`**: Converts GPS data from wardriving captures into a KML file for visualization in Google Earth.

### ☁️ **Data Management & Offloading**
Manage data across devices and overcome the Pineapple's storage limitations.
* **`--utility cloud-sync`**: Integrates `rclone` to provide robust, two-way synchronization of captures and results with a configured cloud provider (Google Drive, Dropbox, etc.).
* **`--tag`**: A full session management system. Tag captures with an operational identifier and use the same tag in the analyzer to focus only on data from a specific engagement.
* **Remote Execution Engine**: Offload any intensive analysis task from the Pineapple to a powerful remote machine, which handles all processing and sends the results back.

### 🚀 **System & Usability**
Get set up and optimized faster than ever.
* **`--utility setup-remote`**: An interactive wizard that fully automates the configuration of a remote analysis server, from SSH key exchange to dependency installation.
* **`--optimize-performance`**: Applies a fine-tuned wireless configuration to the MKVII hardware, capable of boosting capture rates by over 450%.

---

## Requirements
* A WiFi Pineapple MKVII or other OpenWrt-based device.
* **hcxdumptool-custom**: v21.02.0 / 6.3.4 (specifically)
* **hcxtools-custom**: v6.2.7 (specifically)
* **hcxlabtool** (Optional, for advanced backend): v7.0 or newer.
* `git` and `opkg` for installation.
* **Recommended for full functionality:** `rclone` (for cloud-sync) and `macchanger` (for random-mac).
* Root access.

### Support This Project
If you find this project helpful, please consider supporting its continued development:
- **Bitcoin**: `bc1qj85mvdr657nkzef4gppl9xy8eqerqga3suaqc3`

*Your support helps keep this project maintained and improved. Thank you!*
