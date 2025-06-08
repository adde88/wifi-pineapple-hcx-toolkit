Frequently Asked Questions (FAQ)
Table of Contents
General Questions

Installation Issues

Usage Questions

Technical Questions

Troubleshooting

General Questions
What is the WiFi Pineapple HCX Toolkit?
The HCX Toolkit is a powerful wrapper script for hcxdumptool that automates and simplifies WiFi security assessments on the WiFi Pineapple MK7. It adds features like workflow automation, configuration profiles, interactive mode, and smart channel detection.

What's the difference between this and raw hcxdumptool?
This toolkit adds a user-friendly layer on top of hcxdumptool. Key advantages include:

Workflow Automation: Use simple flags like --run-and-crack or --wardriving-loop for complex tasks.

Profiles: Save and load entire configurations with --profile <name>.

Interactive Mode: A guided --interactive setup for new users.

Automatic Setup: The script handles interface validation, directory creation, and process management.

Is this tool free to use?
Yes, the toolkit is released under the GPL-3 license and is free for authorized security testing.

Installation Issues
Q: I ran the --install command but my profiles weren't copied.
A: The installer copies profiles from a profiles/ directory located in the same folder as the script being run. The recommended way to ensure this works is to git clone the entire repository, then run the installer from within the cloned directory.

Q: Where are the files installed?
Main script: /usr/bin/hcxdumptool-launcher

Configuration & Profiles: /etc/hcxtools/

BPF filters: /etc/hcxtools/bpf-filters/

Log File: /etc/hcxtools/launcher.log

Default Captures: /root/hcxdumps/

Usage Questions
Q: What is the easiest way to start?
A: Run the script with the --interactive flag. It will walk you through the most common settings.

hcxdumptool-launcher --interactive

Q: How do I use a profile?
A: First, ensure your profile .conf file is in /etc/hcxtools/profiles/. Then, use the --profile flag with the name of the file (without the .conf extension).

# This will load /etc/hcxtools/profiles/stealth.conf
hcxdumptool-launcher --profile stealth

Q: How can I automatically convert my captures for hashcat?
A: Use the --run-and-crack flag. It will run the capture and then immediately create a .hc22000 file in the same directory if any handshakes were found.

hcxdumptool-launcher -d 300 --run-and-crack

Q: What's the best way to capture while moving (wardriving)?
A: Use the --wardriving-loop mode. It will run captures in a continuous cycle, creating a new file for each loop.

# Capture in 5-minute (300s) loops until stopped with Ctrl+C
hcxdumptool-launcher --wardriving-loop 300

Technical Questions
Q: Why does it say my interface is in monitor mode?
A: hcxdumptool handles monitor mode internally. You must start with the interface in managed mode.

iw wlan2 set type managed

Q: How do I create custom BPF filters?
A: Example for a WPA2-only filter:

# Create with tcpdump
tcpdump -ddd 'wlan type mgt and wlan[0] & 0x0c = 0x08' > /etc/hcxtools/bpf-filters/wpa2-only.bpf

# Use the filter
hcxdumptool-launcher -b /etc/hcxtools/bpf-filters/wpa2-only.bpf

Troubleshooting
Q: The script exits immediately with a "Killed" message.
A: This usually means the device is out of memory. The WiFi Pineapple is a low-resource device. Try these steps:

Run in quiet mode to disable the real-time display, which uses CPU: hcxdumptool-launcher -q

Target a smaller set of channels instead of all of them: hcxdumptool-launcher -c 1,6,11

Stop any other non-essential services on the Pineapple.

Q: My log file at /etc/hcxtools/launcher.log is not being created.
A: The log file is only created after you run the --install command for the first time. If you are running the script directly from a temporary directory, it will not write logs. Run the installer from the cloned repository to set up all the required directories and files.

Q: The --run-and-crack workflow ran, but no .hc22000 file was created.
A: This is expected behavior if no crackable handshakes were captured. hcxpcapngtool will only create the output file if it successfully extracts at least one valid PMKID or EAPOL pair. The script will inform you that no hashes were found in this case.