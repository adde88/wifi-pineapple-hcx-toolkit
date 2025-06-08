Changelog
All notable changes to the WiFi Pineapple HCX Toolkit will be documented in this file.

The format is based on Keep a Changelog,
and this project adheres to Semantic Versioning.

[2.5.0] - 2025-06-08
Changed
Major Code Refactoring: The script has been significantly refactored for better readability and maintainability. Core logic for argument parsing, pre-flight checks, and workflow execution has been moved into dedicated functions.

Unified Argument & Profile Loading: Implemented a single, clean loop to process all command-line arguments and load profiles, removing redundancy.

[2.4.0] - 2025-06-08
Changed
Improved Installation Process: The --install function no longer generates BPF files using tcpdump. Instead, it now copies all .bpf files from a bpf-filters directory located alongside the script, making the installation self-contained and removing tcpdump as an installation dependency.

[2.3.0] - 2025-06-08
Added
Workflow Modes: Introduced powerful workflow arguments to automate common tasks.

--run-and-crack: Automatically converts captures to .hc22000 hash format post-capture.

--wardriving-loop DURATION: Runs the capture in a continuous loop for mobile data collection.

--client-hunt: A convenience flag to optimize settings for capturing client probe requests.

New BPF Filters: Added several new BPF filters for specialized use cases, including deauth-disassoc.bpf, eap-enterprise.bpf, and null-probe-requests.bpf.

[2.2.0] - 2025-06-07
Added
Configuration Profiles: Load predefined settings from .conf files using the --profile <name> argument.

Interactive Mode: A new --interactive flag starts a guided setup for users unfamiliar with all the options.

Logging: The launcher now logs its major actions (start, stop, errors) to /etc/hcxtools/launcher.log.

RCA Scan Mode: Added support for hcxdumptool's --rcascan=active mode via the --rca-scan flag for passive scanning.

[1.0.1] - 2025-06-07
Added
Smart channel detection with --auto-channels flag.

Configurable scan time with --scan-time SEC option.

Interface state preservation and restoration (--no-restore to disable).

Update checking mechanism with --check-updates.

Dedicated BPF filters directory and several new filter examples.

Changed
Significant code refactoring for better POSIX compliance.

Improved first-run detection logic.

Enhanced channel validation with hardware detection.

[1.0.0] - 2025-06-06
Added
Initial Release.

Core hcxdumptool wrapper functionality.

MAC address filtering (whitelist/blacklist).

Multiple attack modes (all, ap, client).

BPF support, GPS logging, and power save management.

Full OpenWRT/WiFi Pineapple MK7 compatibility.