# Getting Started Guide

Welcome to the WiFi Pineapple HCX Toolkit! This guide will walk you through installing the toolkit, running your first capture, and analyzing the results.

## 1. Installation

First, you need to install the toolkit and its dependencies on your WiFi Pineapple.

1.  **Install `git`**: If you don't have it already, install git using `opkg`.
    ```bash
    opkg update && opkg install git
    ```

2.  **Clone the Repository**: Clone the HCX Toolkit from GitHub.
    ```bash
    git clone [https://github.com/adde88/wifi-pineapple-hcx-toolkit.git](https://github.com/adde88/wifi-pineapple-hcx-toolkit.git)
    cd wifi-pineapple-hcx-toolkit
    ```

3.  **Run the Installer**: Execute the installer script. This will check for the correct dependencies and copy the toolkit files to the correct locations on your system.
    ```bash
    ./hcxdumptool-launcher.sh --install
    ```
    Follow any on-screen instructions that appear after installation.

## 2. Your First Capture

The best way to start is by actively hunting for handshakes. This command will use the default `hcxdumptool` backend to deauthenticate clients and capture WPA handshakes for 5 minutes (300 seconds).

```bash
# Run a handshake hunt using your wireless interface (e.g., wlan2) for 300 seconds
hcxdumptool-launcher -i wlan2 --hunt-handshakes -d 300  

## 3. Analyzing your capture  
Once your capture is complete, you can use the powerful ```hcx-analyzer.sh``` script to investigate your findings. The easiest way to start is by launching its interactive menu.  
1. **Run the Analyzer:** Simply execute the script with no arguments.  
```bash
hcx-analyzer.sh
```
2. **Choose a Mode:** An interactive menu will appear, giving you local and remote analysis options. For a first look, select the local ```summary``` option. The analyzer will automatically find your latest capture file and give you a report on the networks, devices, and potential hashes you collected.