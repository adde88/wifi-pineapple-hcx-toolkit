# Installation Guide

This guide provides step-by-step instructions for installing the WiFi Pineapple HCX Toolkit.

## Prerequisites

- WiFi Pineapple MKVII
- `git` and `opkg` installed (`opkg update && opkg install git`)
- Root access via SSH

## Installation Steps

1.  **Clone the Repository**
    ```bash
    git clone [https://github.com/adde88/wifi-pineapple-hcx-toolkit.git](https://github.com/adde88/wifi-pineapple-hcx-toolkit.git)
    cd wifi-pineapple-hcx-toolkit
    ```

2.  **Run the Installer**
    ```bash
    ./hcxdumptool-launcher.sh --install
    ```

3.  **Verify the Installation**
    ```bash
    hcxdumptool-launcher --version
    ```

This will install the toolkit and all its components to the correct directories on your WiFi Pineapple.