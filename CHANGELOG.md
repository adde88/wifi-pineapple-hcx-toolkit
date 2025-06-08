Changelog
All notable changes to the WiFi Pineapple HCX Toolkit will be documented in this file.

The format is based on Keep a Changelog,
and this project adheres to Semantic Versioning.

[2.6.3] - 2025-06-08
Fixed
Restored visibility of the hcxdumptool real-time status display (TUI) by default. The display is now only hidden when using quiet mode (-q).

Added
Re-introduced the interactive confirmation prompt, allowing users to press Enter to start the capture or Ctrl+C to exit.

[2.6.1] - 2025-06-08
Fixed
Resolved a fatal syntax error: unexpected "(" on pure POSIX shells (like ash on OpenWrt) by refactoring the command-building logic to be fully compliant.

[2.6.0] - 2025-06-08
Added
Dry Run Mode: A --dry-run flag was added to show the final command that would be executed without actually running it.

Configuration Listing: Added --list-profiles and --list-filters flags to allow users to quickly see what configuration files are available.

Flexible Export Format: The --run-and-crack workflow can now use a custom hash format specified with the --export-format flag.

Log File Rotation: The script now automatically rotates the launcher.log file when it exceeds 1MB.

[2.5.0] - 2025-06-08
Changed
Major Code Refactoring: The script has been significantly refactored for better readability and maintainability.

Unified Argument & Profile Loading: Implemented a single, clean loop to process all command-line arguments and load profiles.

[2.4.0] - 2025-06-08
Changed
Improved Installation Process: The --install function now copies all .bpf files from a local bpf-filters directory instead of generating them, making the installation self-contained.

[2.3.0] - 2025-06-08
Added
Workflow Modes: Introduced --run-and-crack, --wardriving-loop, and --client-hunt for automating common tasks.

[2.2.0] - 2025-06-07
Added
Configuration Profiles: Load predefined settings from .conf files using the --profile <name> argument.

Interactive Mode: A new --interactive flag starts a guided setup.

Logging: The launcher now logs its major actions to /etc/hcxtools/launcher.log.

RCA Scan Mode: Added support for hcxdumptool's passive scan mode.

[1.0.1] - 2025-06-07
Added
Smart channel detection with --auto-channels flag.

Interface state preservation and restoration.

Update checking mechanism with --check-updates.

[1.0.0] - 2025-06-06
Added
Initial Release.

Core hcxdumptool wrapper functionality.