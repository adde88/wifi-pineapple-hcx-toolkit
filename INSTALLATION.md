# Installation Guide

This guide provides step-by-step instructions for installing the WiFi Pineapple HCX Toolkit v8.0.7.

## Prerequisites

Before installing, please ensure your system meets the following requirements:

* A WiFi Pineapple MKVII or other OpenWrt-based device.
* **hcxdumptool-custom**: v21.02.0 / 6.3.5 or newer installed via `opkg`.
* **hcxtools-custom**: v6.2.7 or newer installed via `opkg`.
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
    Execute the installer script from within the cloned directory. The script will check for dependencies and copy all necessary files to their appropriate locations.
    ```bash
    ./hcxdumptool-launcher.sh --install
    ```
    After the script finishes, proceed to the critical post-installation step below.

3.  **Verify the Installation**
    After the installation completes, you can verify that the tools are ready by running the launcher with the version flag:
    ```bash
    hcxdumptool-launcher --version
    ```
    This should display `v8.0.7` or newer.

## Post-Installation: Performance Tuning (CRITICAL STEP)

The toolkit includes a `wireless.config` file in the cloned repository directory. This file is designed for high-performance capture but contains default credentials.

> [!WARNING]
> **You MUST edit the `wireless.config` file before proceeding.**
>
> 1.  Open the `wireless.config` file in a text editor.
> 2.  Set your own admin network name (SSID) and password.
> 3.  Save the file.
>
> **Failure to do so will result in you being locked out of your admin network after applying the configuration.**

Once you have edited and saved your credentials in `wireless.config`, you can apply the optimized settings. The installer script will guide you through the final steps.

```bash
hcxdumptool-launcher --optimize-performance