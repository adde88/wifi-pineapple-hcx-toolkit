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

## 2. Your First Capture

The easiest way to start is with a simple survey scan to see what networks are around you without performing any attacks.

```bash
# Run a survey scan using your wireless interface (e.g., wlan1)
hcxdumptool-launcher -i wlan1 --survey