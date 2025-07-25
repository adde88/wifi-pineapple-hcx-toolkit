# Installation Guide

This guide provides step-by-step instructions for installing the WiFi Pineapple HCX Toolkit v7.0.0.

## Prerequisites

Before installing, please ensure your system meets the following requirements:

* A WiFi Pineapple MKVII or other OpenWrt-based device.
* **hcxdumptool-custom**: v21.02.0 or newer installed via `opkg`.
* **hcxtools-custom**: v6.2.7-1 or newer installed via `opkg`.
* **hcxlabtool** (Optional): v7.0 or newer for the advanced attack backend.
* **git**: The `git` package must be installed (`opkg update && opkg install git`).
* Root access to the device.

## Installation Steps

1.  **Clone the Repository**
    Log into your device via SSH and run the following commands to clone the toolkit repository:
    ```bash
    git clone [https://github.com/adde88/wifi-pineapple-hcx-toolkit.git](https://github.com/adde88/wifi-pineapple-hcx-toolkit.git)
    cd wifi-pineapple-hcx-toolkit
    ```

2.  **Run the Installer**
    Execute the installer script from within the cloned directory. The script will check for the correct dependencies and copy all necessary files to their appropriate locations on your system.
    ```bash
    ./hcxdumptool-launcher.sh --install
    ```

3.  **Verify the Installation**
    After the installation completes, you can verify that the tools are ready by running the launcher with the version flag:
    ```bash
    hcxdumptool-launcher --version
    ```
    This should display `v7.0.0` or newer. The toolkit is now installed and ready to use.

## Post-Installation: Performance Tuning (Recommended)

This toolkit includes a high-performance wireless configuration that can dramatically increase capture rates. It is highly recommended for all users.

To activate it, run the following command and **carefully read and follow the on-screen instructions**, which require manual steps and a reboot.
```bash
hcxdumptool-launcher --optimize-performance