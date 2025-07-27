## Changelog
All notable changes to the WiFi Pineapple HCX Toolkit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [8.0.0 "Leviathan"] - 2025-07-27

### Added
- **Strategic Recommendation Engine**: (`--mode recommend`) The analyzer now acts as a decision-support system, analyzing captures to suggest the most effective subsequent attack vectors.
- **Automated C2 Callbacks**: The analyzer can now send real-time push notifications via `ntfy` or `Discord` the moment a remote cracking job is successful.
- **Situational Awareness Dashboard**: (`--utility generate-dashboard`) A new utility that generates a single, self-contained HTML report fusing all collected intelligence (cracked PSKs, networks, PII, GPS tracks) into a professional dashboard.
- **Adaptive Deauthentication**: (`--hunt-adaptive`) A new surgical attack mode in the launcher that performs reconnaissance and targets only active clients for deauthentication, maximizing success and minimizing network noise.
- **Chainable Job Queue**: (`--post-job`) The launcher can now automatically trigger the analyzer with specified arguments upon capture completion, enabling a "fire-and-forget" workflow.
- **Credential Reuse Analysis**: (`--utility find-reuse-targets`) A new analyzer utility that cross-references cracked passwords against all uncracked networks with a matching ESSID, identifying prime targets for lateral movement.
- **Historical Trend Analysis**: (`--mode trends`) The analyzer can now query the database to report on long-term environmental changes, such as new devices, stale devices, and recent cracking activity.
- **Turnkey Remote Setup Wizard**: (`--utility setup-remote`) An interactive wizard in the analyzer that automates the entire process of configuring a remote server, from SSH key exchange to dependency installation.
- **Cloud Storage Sync**: (`--utility cloud-sync`) A new analyzer utility that integrates `rclone` to provide robust, two-way synchronization of captures and results with a configured cloud provider.
- **Session Management & Tagging**: (`--tag`) The launcher can now embed a session tag into filenames, and the analyzer can filter its operations by this tag for organized, engagement-based analysis.
- **Evasion & Anonymity**: (`--random-mac`) The launcher can now randomize the capture interface's MAC address before an operation and restore it upon completion.
- **Expanded Remote Execution**: All new data-intensive analysis modes (`recommend`, `trends`, `find-reuse-targets`) have been made available for remote execution.

### Changed
- **Major Version Upgrade**: Version bumped from 7.1.0 to 8.0.0 and codenamed "Leviathan" to reflect the monumental leap in capabilities from a set of tools to an integrated offensive intelligence platform.
- **Configuration (`hcxscript.conf`)**: The configuration file has been updated to support the new notification and cloud sync features.

### Fixed
- **POSIX Compliance**: All new features across both scripts have been meticulously hardened for strict POSIX compliance, resolving multiple `bash`-specific syntax errors to ensure flawless execution on the WiFi Pineapple's `ash` shell.
- **Help Menu Documentation**: All previously undocumented arguments in `hcxdumptool-launcher.sh` have been added to the help menu, exposing the full capabilities of the tool.

## [7.1.0] - 2025-07-26
### Fixed
- **POSIX Compliance**: Corrected a critical syntax error in `hcx-analyzer.sh` caused by non-POSIX `bash` features (process substitution and associative arrays). The `run_find_reuse_targets` function was rewritten to be fully compliant with the `ash` shell.
- **Shebang Correction**: Ensured `hcx-analyzer.sh` uses `#!/bin/sh` to maintain compatibility with the target platform.

## [7.0.0] - 2025-07-25
### Added
- **Performance Optimization Engine**: Added a powerful new feature to dramatically increase capture performance. Users can now apply a custom-tuned wireless configuration file specifically optimized for high-gain antennas and long-range capture on the WiFi Pineapple MKVII.
  - `--optimize-performance`: Backs up the current wireless config and applies the high-performance settings.
  - `--restore-config`: Safely reverts to the original wireless configuration from the backup.
- **System Resilience**: The installer now creates the `/etc/hcxtools/VERSION` file and the `wireless.optimized` template, ensuring the new features work correctly on fresh installations. The uninstaller will also now prompt to restore the wireless config backup if one exists.

### Changed
- **Centralized Versioning System**: Major architectural change. Both `hcxdumptool-launcher.sh` and `hcx-analyzer.sh` no longer have hardcoded version numbers. They now dynamically read the toolkit's version directly from a single source of truth: `/etc/hcxtools/VERSION`. This streamlines version bumps and ensures perfect consistency across the entire toolkit.
- **Code Refinement**: Cleaned up script initialization blocks to implement the new version-fetching logic, slightly improving startup performance and maintainability.

## [7.0.0] - ?? -- Missing Data -- ??

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
**Fixed** - Restored visibility of the hcxdumptool real-time status display (TUI) by default. The display is now only hidden when using quiet mode (-q).

**Added** - Re-introduced the interactive confirmation prompt, allowing users to press Enter to start the capture or Ctrl+C to exit.

## [2.6.1] - 2025-06-08  
**Fixed** - Resolved a fatal syntax error: unexpected "(" on pure POSIX shells (like ash on OpenWrt) by refactoring the command-building logic to be fully compliant.

## [2.6.0] - 2025-06-08  
**Added** - Dry Run Mode: A --dry-run flag was added to show the final command that would be executed without actually running it.
- Configuration Listing: Added --list-profiles and --list-filters flags to allow users to quickly see what configuration files are available.
- Flexible Export Format: The --run-and-crack workflow can now use a custom hash format specified with the --export-format flag.
- Log File Rotation: The script now automatically rotates the launcher.log file when it exceeds 1MB.

## [2.5.0] - 2025-06-08  
**Changed** - Major Code Refactoring: The script has been significantly refactored for better readability and maintainability.
- Unified Argument & Profile Loading: Implemented a single, clean loop to process all command-line arguments and load profiles.

## [2.4.0] - 2025-06-08  
**Changed** - Improved Installation Process: The --install function now copies all .bpf files from a local bpf-filters directory instead of generating them, making the installation self-contained.

## [2.3.0] - 2025-06-08  
**Added** - Workflow Modes: Introduced --run-and-crack, --wardriving-loop, and --client-hunt for automating common tasks.

## [2.2.0] - 2025-06-07  
**Added** - Configuration Profiles: Load predefined settings from .conf files using the --profile <name> argument.
- Interactive Mode: A new --interactive flag starts a guided setup.
- Logging: The launcher now logs its major actions to /etc/hcxtools/launcher.log.
- RCA Scan Mode: Added support for hcxdumptool's passive scan mode.

## [1.0.1] - 2025-06-07  
**Added** - Smart channel detection with --auto-channels flag.
- Interface state preservation and restoration.
- Update checking mechanism with --check-updates.

## [1.0.0] - 2025-06-06  
**Added** Initial Release.
Core hcxdumptool wrapper functionality.