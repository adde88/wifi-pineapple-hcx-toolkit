# Frequently Asked Questions (FAQ)

## Table of Contents
* [General Questions](#general-questions)
* [Installation Issues](#installation-issues)
* [Usage Questions](#usage-questions)
* [Technical Questions](#technical-questions)
* [Troubleshooting](#troubleshooting)

## General Questions
### What is the WiFi Pineapple HCX Toolkit?
The HCX Toolkit is a powerful wrapper script for `hcxdumptool` that automates and simplifies WiFi security assessments on the WiFi Pineapple MK7. It adds features like workflow automation, configuration profiles, and reliable interface management.

### What's the difference between this and raw hcxdumptool?
This toolkit adds a user-friendly layer on top of `hcxdumptool`. Key advantages include:
* **Workflow Automation**: Use simple flags like `--wardriving-loop` for complex tasks.
* **Profiles**: Save and load entire configurations with `--profile <name>`.
* **Interactive Analyzer**: The companion `hcx-analyzer.sh` script runs interactively, guiding you through different analysis types.
* **Automatic Setup**: The script handles interface validation, directory creation, and process management.

## Installation Issues
### Q: Where are the files installed?
* **Main scripts**: `/usr/bin/hcxdumptool-launcher` and `/usr/bin/hcx-analyzer.sh`
* **Configuration & Profiles**: `/etc/hcxtools/`
* **BPF filters**: `/etc/hcxtools/bpf-filters/`
* **Log File**: `/etc/hcxtools/launcher.log`
* **Default Captures**: `/root/hcxdumps/`

## Usage Questions
### Q: What is the easiest way to start analyzing captures?
A: Run the analyzer script without any arguments. It will present an interactive menu.
```bash
hcx-analyzer.sh