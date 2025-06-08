WiFi Pineapple HCX Toolkit 🍍
A powerful and user-friendly launcher script for hcxdumptool on the WiFi Pineapple MK7. Automate your WiFi security assessments with advanced features, workflow automation, and full OpenWRT compatibility.

🌟 Features
Workflow Automation:

--run-and-crack: Automatically convert captures to a specified hash format post-capture.

--wardriving-loop: Run captures in a continuous loop for mobile data collection.

--client-hunt: A one-switch mode to optimize settings for finding and capturing client devices.

Configuration & Debugging:

--profile <name>: Load pre-defined sets of arguments for specific scenarios.

--interactive: A guided setup that prompts you for the most common options.

--dry-run: Preview the exact hcxdumptool command before executing.

--list-profiles & --list-filters: See all available configurations at a glance.

Smart Interface & Channel Management: Validates interface modes and can automatically find and target the busiest channels.

Advanced Filtering: Use MAC whitelists/blacklists and advanced Berkeley Packet Filters (BPF).

Log Rotation: Automatically manages log file size to prevent storage issues on long-running devices.

📋 Requirements
WiFi Pineapple MK7 (or any OpenWRT device)

hcxdumptool v21.02.0 or newer

hcxtools (optional, but highly recommended for analysis)

git (for installation)

Root access

🚀 Quick Start
Clone the Repository:

opkg update && opkg install git
git clone [https://github.com/adde88/wifi-pineapple-hcx-toolkit.git](https://github.com/adde88/wifi-pineapple-hcx-toolkit.git)
cd wifi-pineapple-hcx-toolkit

Run the Installer:
The installer copies the main script to your PATH and sets up configuration directories, including profiles and BPF filters.

chmod +x hcxdumptool-launcher.sh
./hcxdumptool-launcher.sh --install

Run Your First Capture:
Now you can run the launcher from anywhere.

# See what profiles you have available
hcxdumptool-launcher --list-profiles

# Run a quick client hunt and see what command would be used
hcxdumptool-launcher --client-hunt -d 180 --dry-run

📖 Usage
Basic Examples
# Run with a pre-defined aggressive profile
hcxdumptool-launcher --profile aggressive

# Target channel 6, then convert to WPA-PMKID-PBKDF2 format (16800)
hcxdumptool-launcher -c 6 -d 300 --run-and-crack --export-format 16800

# Start a wardriving session, capturing in 10-minute loops
hcxdumptool-launcher --wardriving-loop 600

All Options
For a full list of commands and options, run:

hcxdumptool-launcher --help

⚠️ Legal Disclaimer
IMPORTANT: This tool is for authorized security testing only! Unauthorized access to computer networks is illegal. Users are responsible for complying with all applicable laws.

🤝 Contributing
Contributions are welcome! Please fork the repository and create a pull request with your improvements.

📄 License
This project is licensed under the GNU General Public License v3.0.

## Support This Project

If you find this project helpful, please consider supporting its continued development:

- **Bitcoin**: Scan the QR code below or use the address  
  **`bc1qj85mvdr657nkzef4gppl9xy8eqerqga3suaqc3`**
  
  ![BTC Donation QR Code](assets/qr-btc-address-200.png)

- **Contribute**: Pull requests and bug reports are always welcome!

Your support helps keep this project maintained and improved. Thank you! ❤️
