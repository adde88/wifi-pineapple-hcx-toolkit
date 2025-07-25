# Frequently Asked Questions (FAQ)

## Table of Contents
* [General Questions](#general-questions)
* [Installation & Usage](#installation--usage)
* [Technical Questions](#technical-questions)

## General Questions
### What is the WiFi Pineapple HCX Toolkit?
The HCX Toolkit is a powerful wrapper script framework for the `hcx` tool suite that automates and simplifies WiFi security assessments on the WiFi Pineapple. It adds features like a remote execution engine, selectable attack backends, performance optimization, configuration profiles, and a full-featured analyzer.

### What's the difference between this and the raw hcx tools?
This toolkit adds a user-friendly and feature-rich layer. Key advantages include:
* **Remote Execution**: Offload heavy analysis and cracking to a powerful desktop PC.
* **Performance Optimization**: A one-command option to apply a high-gain wireless configuration.
* **Dual Backends**: Choose between `hcxdumptool` for broad captures and `hcxlabtool` for surgical attacks.
* **Workflow Automation**: Use simple flags like `--wardriving-loop` and `--hunt-handshakes` for complex tasks.
* **Interactive Analyzer**: The companion `hcx-analyzer.sh` script runs interactively, guiding you through different analysis types locally or remotely.
* **Advanced Filtering**: Filter captures by MAC/OUI in real-time or filter hash files by dozens of criteria post-capture.

## Installation & Usage
### Q: Where are the files installed?
* **Main scripts**: `/usr/bin/hcxdumptool-launcher` and `/usr/bin/hcx-analyzer.sh`
* **Configuration & Data**: The entire `/etc/hcxtools/` directory, which contains:
    * `hcxscript.conf` (Main config, including remote server settings)
    * `profiles/` (Capture profiles)
    * `launcher.log` (Log file)
    * `VERSION` (Toolkit version file)
    * `wireless.optimized` (Template for the performance optimization)
* **Default Captures**: `/root/hcxdumps/`
* **Default Analysis Dir**: `/root/hcx-analysis/`
* **Wireless Backup**: `/etc/config/wireless.hcx-backup` (Created after running `--optimize-performance`)

### Q: What is the easiest way to start analyzing captures?
A: Run the analyzer script without any arguments. It will present an interactive menu.
```bash
hcx-analyzer.sh
```

From this menu, you can choose local analysis modes (like ```summary``` or ```vuln```) or even offload the work by selecting a remote option. The script will automatically find your most recent capture files.  

## Technical Questions  
**Q: What is remote analysis and why should I use it?**  
A: The WiFi Pineapple has a limited CPU and RAM. Heavy tasks, like analyzing a large capture file with thousands of networks, can be very slow or even crash the device. Remote analysis solves this by sending the capture file to a more powerful computer to do the work and then brings back the results. It's much faster and more reliable for large data sets.  

Q: What is the difference between --backend hcxdumptool and --backend hcxlabtool?  
A: They are two different capture engines for different purposes.  
* ```--backend hcxdumptool``` (the default) is the classic, all-around tool. It's great for capturing everything in an area (both PMKIDs from APs and handshakes from clients).
* ```--backend hcxlabtool``` is a newer, more specialized tool. Use it when you want to perform a "surgical" attack, such as only collecting PMKIDs, or only targeting clients without interacting with access points.
