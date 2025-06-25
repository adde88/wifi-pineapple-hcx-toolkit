## Changelog
All notable changes to the WiFi Pineapple HCX Toolkit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [5.0.0] - 2025-06-25
### Added
- **Interactive Analyzer Menu**: The `hcx-analyzer.sh` script now presents an interactive menu if run without arguments, guiding the user through analysis modes.
- **Selectable Summary Modes**: Users can now choose between a `quick` and `deep` summary analysis via the interactive menu or the `--summary-mode` flag.
- **Advanced Intelligence Mode**: Added a new `--mode intel` to `hcx-analyzer.sh` for deep analysis of device vendors and hash grouping.
- **Remote Cracking Offload**: Implemented a `--mode remote-crack` in `hcx-analyzer.sh` to securely transfer hash files to a remote machine for cracking with `hashcat`.
- **Configuration-driven Settings**: Remote cracking settings are now managed in `/etc/hcxtools/hcxscript.conf`.
- **Visual Feedback Spinner**: Added a spinner animation to `hcx-analyzer.sh` to provide visual feedback during long operations.
- **Verbose Debugging Mode**: A `-v` / `--verbose` flag was added to `hcx-analyzer.sh` for easier troubleshooting.

### Changed
- **Major Version Bump**: Updated version from 4.x to 5.0.0 to reflect the massive feature overhaul and bug fixes.
- **Improved Dependency Checking**: The launcher now uses the much faster `-v` flag on the binaries themselves instead of the slow `opkg info` command.
- **Robust Interface Handling**: The launcher now proactively sets the wireless interface to `managed` mode at the start and reliably restores it to `managed` mode on exit, resolving major bugs.

### Fixed
- **`--hunt-handshakes`**: Corrected a critical bug where the script used a non-existent `--active_deauth` flag, causing it to fail.
- **`--auto-channels`**: Fixed a bug where running this flag without an interface would cause the script to hang. It now provides a helpful error message.
- **`hcx-analyzer.sh` Hanging**: Resolved a persistent issue where the analyzer script would hang during file processing by simplifying command execution logic.

### Removed
- **`--wps-scan`**: Removed this non-functional feature entirely from the launcher, as `hcxdumptool` does not support the required scanning method.

## [4.0.9] - (Previous public release)
### Added
- **Easy Modes / Personas:**
  - `--survey`: Adds a non-intrusive network survey mode.
  - `--passive`: Implements a 100% passive listening mode by disabling all attack transmissions.
  - `--enable-gps`: Simplifies GPS wardriving by integrating with gpsd.

- **Intelligent Automation:**
  - `--auto-channels`: Implements a smart pre-scan to automatically target the busiest channels.
  - `--run-and-crack`: Enhances post-capture workflow to automatically generate a full suite of analysis files (hashes, wordlists) using hcxpcapngtool's --prefix option.

- **System & Management Utilities:**
  - `--update-oui`: Adds a utility to download the latest IEEE OUI list, with checksum verification to prevent redundant downloads.
  - `--create-profile`: Re-implements an interactive guide to create and save user-defined capture profiles.

- **Robustness & Reliability:**
  - Adds an intelligent dependency check that verifies the installed `hcxdumptool` version against the expected version, warning the user of potential mismatches.
  - Improves POSIX compliance and formatting to ensure stability on minimalist shells like the WiFi Pineapple's `ash`.

Fixes:
- Resolves a syntax error related to shell redirection in the `start_capture` function.
- Corrects script logic to prevent duplicated function definitions.

## [2.6.3] - 2025-06-08  
**Fixed**  
- Restored visibility of the hcxdumptool real-time status display (TUI) by default. The display is now only hidden when using quiet mode (-q).  

**Added**  
- Re-introduced the interactive confirmation prompt, allowing users to press Enter to start the capture or Ctrl+C to exit.  

## [2.6.1] - 2025-06-08  
**Fixed**  
- Resolved a fatal syntax error: unexpected "(" on pure POSIX shells (like ash on OpenWrt) by refactoring the command-building logic to be fully compliant.  

## [2.6.0] - 2025-06-08  
**Added**  
- Dry Run Mode: A --dry-run flag was added to show the final command that would be executed without actually running it.  
- Configuration Listing: Added --list-profiles and --list-filters flags to allow users to quickly see what configuration files are available.  
- Flexible Export Format: The --run-and-crack workflow can now use a custom hash format specified with the --export-format flag.  
- Log File Rotation: The script now automatically rotates the launcher.log file when it exceeds 1MB.  

## [2.5.0] - 2025-06-08  
**Changed**  
- Major Code Refactoring: The script has been significantly refactored for better readability and maintainability.  
- Unified Argument & Profile Loading: Implemented a single, clean loop to process all command-line arguments and load profiles.  

## [2.4.0] - 2025-06-08  
**Changed**  
- Improved Installation Process: The --install function now copies all .bpf files from a local bpf-filters directory instead of generating them, making the installation self-contained.  

## [2.3.0] - 2025-06-08  
**Added**  
- Workflow Modes: Introduced --run-and-crack, --wardriving-loop, and --client-hunt for automating common tasks.  

## [2.2.0] - 2025-06-07  
**Added**  
- Configuration Profiles: Load predefined settings from .conf files using the --profile <name> argument.  
- Interactive Mode: A new --interactive flag starts a guided setup.  
- Logging: The launcher now logs its major actions to /etc/hcxtools/launcher.log.  
- RCA Scan Mode: Added support for hcxdumptool's passive scan mode.  

## [1.0.1] - 2025-06-07  
**Added**  
- Smart channel detection with --auto-channels flag.  
- Interface state preservation and restoration.  
- Update checking mechanism with --check-updates.  

## [1.0.0] - 2025-06-06  
**Added**  
Initial Release.  
Core hcxdumptool wrapper functionality.  
