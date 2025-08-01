#!/bin/sh
#
# v8.0.7 "Leviathan"
# Author: Andreas Nilsen
# Github: https://www.github.com/ZerBea/hcxtools
# Refactored to use an external wireless config file.
#
# This script is designed to work with the custom packages from:
# https://github.com/adde88/openwrt-useful-tools
# Adapted for the merged hcxdumptool v6.3.5 and full POSIX compliance.

# --- Add sbin to PATH to ensure system binaries are found ---
export PATH="/usr/sbin:/sbin:$PATH"

#--- Script Information and Constants ---#
readonly INSTALL_DIR="/etc/hcxtools"
readonly CONFIG_FILE="$INSTALL_DIR/hcxscript.conf"
readonly PROFILE_DIR="$INSTALL_DIR/profiles"
readonly BPF_DIR="$INSTALL_DIR/bpf-filters"
readonly LOG_FILE="$INSTALL_DIR/launcher.log"
readonly INSTALL_BIN="/usr/bin/hcxdumptool-launcher"
readonly ANALYZER_BIN="/usr/bin/hcx-analyzer.sh"
readonly UPDATE_URL="https://raw.githubusercontent.com/adde88/wifi-pineapple-hcx-toolkit/main/hcxdumptool-launcher.sh"
readonly VERSION_FILE="$INSTALL_DIR/VERSION"
# The backup file for the original wireless configuration.
readonly WIRELESS_CONFIG_BACKUP="/etc/config/wireless.hcx-backup"

# --- Tool Binaries ---
readonly HCXDUMPTOOL_BIN="/usr/sbin/hcxdumptool"

# --- Dynamically read script version ---
if [ -f "$VERSION_FILE" ]; then
    SCRIPT_VERSION=$(cat "$VERSION_FILE")
else
    SCRIPT_VERSION="8.0.7"
fi

#--- Tool Requirements ---#
readonly REQ_HCXDUMPTOOL_VER_STR="v21.02.0"
readonly REQ_HCXTOOLS_VER_STR="6.2.7"

#--- Color Codes ---#
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m';
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

#--- Default Settings ---#
HCXD_OPTS=""
OUTPUT_DIR="/root/hcxdumps"
INTERFACE=""
CHANNELS=""
DURATION=""
STAY_TIME=""
BPF_FILE=""
FILTER_FILE=""          
FILTER_MODE="blacklist" 
OUI_FILE=""             
OUI_FILTER_MODE="blacklist"
INTERACTIVE_MODE=0
ENABLE_GPS=0
WARDRIVING_LOOP=0
ADAPTIVE_HUNT=0
PASSIVE_MODE=0
SURVEY_MODE=0
SURVEY_SCAN_MODE="a" # 'a' for active, 'p' for passive
ACK_FRAMES=0
TIMEOUT=""
WATCHDOG_MAX=""
ERROR_MAX=""
EXIT_ON_EAPOL=""
ASSOCIATION_MAX=""
M2_MAX=""
RESTORE_INTERFACE=1
HCX_PID=0
TEMP_FILE="/tmp/hcx_session_files_$$"
START_TIME=0
LAST_CAPTURE_FILE=""

#==============================================================================
# HELPER FUNCTIONS
#==============================================================================

log_message() {
    if [ ! -d "$INSTALL_DIR" ]; then return; fi
    if [ -f "$LOG_FILE" ] && [ "$(wc -c < "$LOG_FILE" 2>/dev/null)" -gt 1048576 ]; then
        mv "$LOG_FILE" "$LOG_FILE.old" 2>/dev/null
    fi
    printf "%s - %s\n" "$(date -u +'%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE"
}

show_banner() {
    printf "%b" "${CYAN}\n"
    printf "  _   _  ____  _  _  ____  ____  __  __  _   _ \n"
    printf " ( )_( )( ___)( )/ )( ___)(  _ \\(  )(  )( )_( )\n"
    printf "  ) _ (  )__)  )  (  )__)  )   / )(__)(  \\   / \n"
    printf " (_) (_)(____)(_)\\_)(____)(_)\\_)(______)(_)\\_)\n"
    printf "${CYAN}             WiFi Pineapple HCX Toolkit v%s \"Hydra-Intel\"${NC}\n" "$SCRIPT_VERSION"
    printf "${RED}    LEGAL WARNING: For Authorized Security Personnel ONLY!${NC}\n\n"
}

usage() {
    local SCRIPT_CMD
    SCRIPT_CMD=$(basename "$0")
    printf "${BLUE}Usage:${NC} %s -i <interface> [OPTIONS]\n\n" "$SCRIPT_CMD"
    printf "${GREEN}System & Management:${NC}\n"
    printf "  --install                Install script and all components.\n"
    printf "  --uninstall              Remove the toolkit and all related files.\n"
    printf "  --update                 Check for and install updates to the toolkit.\n"
    printf "  --optimize-performance   Apply the high-performance wireless configuration.\n"
    printf "  --restore-config         Restore the original wireless configuration.\n"
    printf "  --interactive            Start the script in an interactive setup wizard.\n"
    printf "  --profile <name>         Load a configuration profile.\n\n"
    
    printf "${GREEN}Core Capture Options:${NC}\n"
    printf "  -i, --interface <iface>  [REQUIRED] Specify the wireless interface for capture.\n"
    printf "  -c, --channels <ch>      Set specific channels to scan (e.g., '1a,6a,11a'). Default: All.\n"
    printf "  -F                       Use all available channels from the interface.\n"
    printf "  -t, --stay-time <secs>   Set minimum time in seconds to stay on each channel (--t).\n"
    printf "  -d, --duration <secs>    Set the total capture duration in seconds.\n"
    printf "  --enable-gps             Enable gpsd for logging location data (--gpsd).\n\n"

    printf "${GREEN}Attack & Capture Modes (all use hcxdumptool):${NC}\n"
    printf "  --hunt-adaptive          Run a smart hunt that targets a specific AP.\n"
    printf "  --passive                Run in strictly passive mode (sends no deauth/disassoc frames).\n"
    printf "  --survey [a|p]           Perform a network survey (a=active, p=passive). Default: active.\n"
    printf "  --client-only-hunt       Stealthily capture client handshakes (sets --associationmax=0).\n"
    printf "  --pmkid-priority-hunt    Focus on capturing PMKIDs (sets --m2max=0).\n"
    printf "  --time-warp-attack       Execute a Forced Transition Candidate (FTC) attack (--ftc).\n"
    printf "  --wardriving-loop <secs> Run in a continuous loop, creating a new file every N seconds.\n\n"
    
    printf "${GREEN}Fine-Tuning & Automation:${NC}\n"
    printf "  --ack-frames             Acknowledge incoming frames (-A). Requires active monitor mode.\n"
    printf "  --rds <mode>             Set Real-Time Display mode (0-3).\n"
    printf "  --timeout <mins>         Set a total session timeout in minutes (--tot).\n"
    printf "  --watchdog-max <secs>    Set watchdog timeout for no packets received (--watchdogmax).\n"
    printf "  --error-max <count>      Set maximum allowed errors before exit (--errormax).\n"
    printf "  --exit-on-eapol <bm>     Exit after capturing a specific EAPOL frame (bitmask).\n"
    printf "  --association-max <num>  Set max association attempts (--associationmax).\n"
    printf "  --m2-max <num>           Set max M1M2ROGUE frames to receive (--m2max).\n\n"

    printf "${GREEN}Advanced & Other Options:${NC}\n"
    printf "  -h, --help               Show this help screen.\n"
    printf "  -v, --version            Show script version.\n"
    printf "  --hcxd-opts \"<opts>\"     Pass additional, quoted options directly to hcxdumptool.\n\n"
}

install_script() {
    printf "%b\n" "${BLUE}=== Installing HCX Toolkit v%s ===${NC}" "$SCRIPT_VERSION"
    
    if ! command -v "$HCXDUMPTOOL_BIN" >/dev/null 2>&1; then printf "%b\n" "${RED}Required 'hcxdumptool' not found at %s. Aborting.${NC}" "$HCXDUMPTOOL_BIN"; exit 1; fi
    if ! command -v hcxpcapngtool >/dev/null 2>&1; then printf "%b\n" "${RED}Core 'hcxtools' not found. Aborting.${NC}"; exit 1; fi

    printf "Creating directories...\n"
    mkdir -p "$INSTALL_DIR" "$OUTPUT_DIR" "$PROFILE_DIR" "$BPF_DIR"
    
    printf "Installing launcher to %s...\n" "$INSTALL_BIN"
    cp "$0" "$INSTALL_BIN" && chmod +x "$INSTALL_BIN"

    if [ -f "$(dirname "$0")/hcx-analyzer.sh" ]; then
        printf "Installing analyzer to %s...\n" "$ANALYZER_BIN"
        cp "$(dirname "$0")/hcx-analyzer.sh" "$ANALYZER_BIN" && chmod +x "$ANALYZER_BIN"
    fi
    
    echo "$SCRIPT_VERSION" > "$VERSION_FILE"
    touch "$LOG_FILE"
    
    printf "%b\n" "${GREEN}Installation complete!${NC}"
    printf "\n"
    # --- IMPROVED POST-INSTALLATION WARNING ---
    printf "%b\n" "${YELLOW}#################### CRITICAL POST-INSTALL ACTION REQUIRED ####################${NC}"
    printf "%b\n" "${CYAN}This toolkit includes a 'wireless.config' file for high-performance capture.${NC}"
    printf "\n"
    printf "%b\n" "${RED}!!! IMPORTANT WARNING !!!${NC}"
    printf "%b\n" "${YELLOW}The provided 'wireless.config' contains pre-configured settings, including${NC}"
    printf "%b\n" "${YELLOW}an SSID ('MK7-ADMIN') and a default password ('option key ...').${NC}"
    printf "\n"
    printf "%b\n" "${RED}You MUST edit the 'wireless.config' file and set your own password${NC}"
    printf "%b\n" "${RED}before applying it. Failure to do so will prevent you from connecting${NC}"
    printf "%b\n" "${RED}to your device's admin network!${NC}"
    printf "\n"
    printf "%b\n" "${CYAN}1. Edit the 'wireless.config' file with your desired admin password.${NC}"
    printf "%b\n" "${CYAN}2. Apply the configuration by running the following command:${NC}"
    printf "%b\n" "   ${GREEN}hcxdumptool-launcher --optimize-performance${NC}"
    printf "\n"
    printf "%b\n" "${CYAN}A backup of your original settings will be created at:${NC}"
    printf "%b\n" "   ${CYAN}/etc/config/wireless.hcx-backup${NC}"
    printf "%b\n" "${CYAN}You can restore it anytime by running:${NC}"
    printf "%b\n" "   ${GREEN}hcxdumptool-launcher --restore-config${NC}"
    printf "%b\n" "${YELLOW}###############################################################################${NC}"
}

uninstall_script() {
    printf "%b\n" "${YELLOW}--- HCX Toolkit Uninstaller ---${NC}"
    
    if [ -f "$WIRELESS_CONFIG_BACKUP" ]; then
        printf "%b\n" "${YELLOW}A backup of your original wireless configuration was found.${NC}"
        printf "Do you want to restore it now? [y/N] "
        read -r restore_response
        if [ "$restore_response" = "y" ] || [ "$restore_response" = "Y" ]; then
            restore_performance_config
        fi
    fi

    printf "%b\n" "${RED}WARNING: This will permanently remove the following:${NC}"
    printf " - %s\n" "$INSTALL_BIN"
    printf " - %s\n" "$ANALYZER_BIN"
    printf " - The entire configuration directory: %s\n" "$INSTALL_DIR"
    printf "\nAre you sure you want to continue? [y/N] "
    read -r response
    
    case "$response" in
        [yY][eE][sS]|[yY])
            printf "Removing files...\n"
            rm -f "$INSTALL_BIN" 2>/dev/null
            rm -f "$ANALYZER_BIN" 2>/dev/null
            rm -rf "$INSTALL_DIR" 2>/dev/null
            printf "%b\n" "${GREEN}HCX Toolkit has been uninstalled.${NC}"
            ;;
        *)
            printf "Uninstallation cancelled.\n"
            ;;
    esac
}

update_script() {
    printf "%b\n" "${BLUE}=== Checking for updates... ===${NC}"
    local remote_version_line
    remote_version_line=$(wget -qO- "$UPDATE_URL" 2>/dev/null | grep '# v[0-9]\{1,2\}\.[0-9]\{1,2\}\.[0-9]\{1,2\}')
    
    if [ $? -ne 0 ] || [ -z "$remote_version_line" ]; then
        printf "%b\n" "${RED}Error: Could not download update information. Please check internet connection.${NC}"
        exit 1
    fi
    
    local REMOTE_VERSION
    REMOTE_VERSION=$(echo "$remote_version_line" | head -n 1 | cut -d'"' -f2 | cut -d' ' -f1)

    case "$REMOTE_VERSION" in
        ""|*[!0-9.]*)
            printf "${RED}Error: Could not parse a valid remote version. Got: '%s'${NC}\n" "$REMOTE_VERSION"
            exit 1
            ;;
    esac

    if [ "$REMOTE_VERSION" = "$SCRIPT_VERSION" ]; then
        printf "%b\n" "${GREEN}You are already running the latest version ($SCRIPT_VERSION).${NC}"
    else
        printf "%b\n" "${YELLOW}A new version ($REMOTE_VERSION) is available. Updating...${NC}"
        if wget -qO "$INSTALL_BIN.tmp" "$UPDATE_URL"; then
            mv "$INSTALL_BIN.tmp" "$INSTALL_BIN"
            chmod +x "$INSTALL_BIN"
            echo "$REMOTE_VERSION" > "$VERSION_FILE"
            printf "%b\n" "${GREEN}Update complete! You are now on version $REMOTE_VERSION.${NC}"
        else
            printf "%b\n" "${RED}Error: Failed to download the new version.${NC}"
            rm -f "$INSTALL_BIN.tmp"
        fi
    fi
}

#
# REFACTORED FUNCTION
# This function now copies an external config file instead of using a hard-coded one.
#
optimize_performance() {
    printf "%b\n" "${CYAN}--- Applying High-Performance Wireless Configuration ---${NC}"
    
    # The source file is expected to be in the same directory as the script.
    # Its name must be 'wireless.config'.
    local source_config_file
    source_config_file="$(dirname "$0")/wireless.config"

    # First, check if the source configuration file actually exists.
    if [ ! -f "$source_config_file" ]; then
        printf "%b\n" "${RED}Error: Optimized configuration file not found at:${NC}"
        printf "%s\n" "$source_config_file"
        printf "%b\n" "${YELLOW}Please ensure 'wireless.config' is in the same directory as the launcher script.${NC}"
        exit 1
    fi

    # Then, check if the target system file exists.
    if [ ! -f /etc/config/wireless ]; then
        printf "%b\n" "${RED}Error: System wireless configuration not found at /etc/config/wireless.${NC}"
        exit 1
    fi

    # Backup the current configuration before overwriting it.
    if [ -f "$WIRELESS_CONFIG_BACKUP" ]; then
        printf "%b\n" "${YELLOW}A backup already exists at %s. Overwriting it.${NC}" "$WIRELESS_CONFIG_BACKUP"
    else
        printf "Backing up current wireless configuration to %s...\n" "$WIRELESS_CONFIG_BACKUP"
    fi
    cp /etc/config/wireless "$WIRELESS_CONFIG_BACKUP"

    # Copy the new optimized configuration into place.
    printf "Copying optimized configuration from %s...\n" "$source_config_file"
    cp "$source_config_file" /etc/config/wireless

    printf "%b\n" "${GREEN}Performance configuration applied successfully.${NC}"
    printf "Reloading wireless services to apply changes...\n"
    # This command reloads the wireless configuration on OpenWrt.
    wifi reload
    printf "%b\n" "${CYAN}To restore your original settings, run: hcxdumptool-launcher --restore-config${NC}"
}

restore_performance_config() {
    printf "%b\n" "${CYAN}--- Restoring Original Wireless Configuration ---${NC}"
    if [ ! -f "$WIRELESS_CONFIG_BACKUP" ]; then
        printf "%b\n" "${RED}Error: No backup file found at %s. Nothing to restore.${NC}" "$WIRELESS_CONFIG_BACKUP"
        exit 1
    fi

    printf "Restoring from %s...\n" "$WIRELESS_CONFIG_BACKUP"
    # Use mv to both restore the file and remove the backup in one step.
    mv "$WIRELESS_CONFIG_BACKUP" /etc/config/wireless

    printf "%b\n" "${GREEN}Original configuration restored successfully.${NC}"
    printf "Reloading wireless services to apply changes...\n"
    wifi reload
}   

load_profile() {
    local profile_name="$1"
    local profile_path="$PROFILE_DIR/$profile_name.conf"

    if [ ! -f "$profile_path" ]; then
        printf "${RED}Error: Profile '%s' not found at '%s'${NC}\n" "$profile_name" "$profile_path" >&2
        exit 1
    fi

    printf "${CYAN}Loading profile: %s${NC}\n" "$profile_name"
    . "$profile_path"
}

generate_bpf_from_mac_list() {
    if [ -z "$FILTER_FILE" ]; then return; fi
    if [ ! -f "$FILTER_FILE" ]; then
        printf "${RED}Error: Filter file not found at '%s'${NC}\n" "$FILTER_FILE" >&2
        exit 1
    fi

    printf "${CYAN}Generating BPF from MAC list: %s (Mode: %s)${NC}\n" "$FILTER_FILE" "$FILTER_MODE"

    local bpf_string=""
    local mac_list
    mac_list=$(grep -v '^[[:space:]]*#' "$FILTER_FILE" | grep -v '^[[:space:]]*$')

    if [ -z "$mac_list" ]; then
        printf "${YELLOW}Warning: Filter file is empty. Ignoring.${NC}\n"
        return
    fi

    while IFS= read -r mac; do
        mac_clean=$(echo "$mac" | tr -d ':-[:space:]')
        if [ -z "$bpf_string" ]; then
            bpf_string="wlan addr2 $mac_clean"
        else
            bpf_string="$bpf_string or wlan addr2 $mac_clean"
        fi
    done <<EOF
$mac_list
EOF

    if [ "$FILTER_MODE" = "blacklist" ]; then
        bpf_string="not ($bpf_string)"
    fi

    local temp_bpf_file="/tmp/hcx_mac_filter_$$.bpf"
    if hcxdumptool --bpfc="$bpf_string" > "$temp_bpf_file"; then
        BPF_FILE="$temp_bpf_file"
        printf "Successfully created temporary BPF filter.\n"
    else
        printf "${RED}Error: Failed to compile BPF from MAC list.${NC}\n" >&2
        exit 1
    fi
}

generate_bpf_from_oui_list() {
    if [ -z "$OUI_FILE" ]; then return; fi
    if [ ! -f "$OUI_FILE" ]; then
        printf "${RED}Error: OUI file not found at '%s'${NC}\n" "$OUI_FILE" >&2
        exit 1
    fi

    printf "${CYAN}Generating BPF from OUI list: %s (Mode: %s)${NC}\n" "$OUI_FILE" "$OUI_FILTER_MODE"

    local bpf_string=""
    local oui_list
    oui_list=$(grep -v '^[[:space:]]*#' "$OUI_FILE" | grep -v '^[[:space:]]*$')

    if [ -z "$oui_list" ]; then
        printf "${YELLOW}Warning: OUI file is empty. Ignoring.${NC}\n"
        return
    fi

    while IFS= read -r oui; do
        local octet1
        octet1=$(echo "$oui" | cut -d: -f1 | tr 'a-f' 'A-F')
        local octet2
        octet2=$(echo "$oui" | cut -d: -f2 | tr 'a-f' 'A-F')
        local octet3
        octet3=$(echo "$oui" | cut -d: -f3 | tr 'a-f' 'A-F')

        local oui_filter_part="(wlan[10] = 0x$octet1 and wlan[11] = 0x$octet2 and wlan[12] = 0x$octet3)"

        if [ -z "$bpf_string" ]; then
            bpf_string="$oui_filter_part"
        else
            bpf_string="$bpf_string or $oui_filter_part"
        fi
    done <<EOF
$oui_list
EOF

    bpf_string="wlan addr2 and ($bpf_string)"

    if [ "$OUI_FILTER_MODE" = "blacklist" ]; then
        bpf_string="not ($bpf_string)"
    fi

    local temp_bpf_file="/tmp/hcx_oui_filter_$$.bpf"
    if hcxdumptool --bpfc="$bpf_string" > "$temp_bpf_file"; then
        BPF_FILE="$temp_bpf_file"
        printf "Successfully created temporary OUI BPF filter.\n"
    else
        printf "${RED}Error: Failed to compile BPF from OUI list.${NC}\n" >&2
        exit 1
    fi
}

dependency_check() {
    printf "${CYAN}--- Verifying Dependencies ---${NC}\n"
    local error=0

    if ! command -v hcxpcapngtool >/dev/null 2>&1 || ! hcxpcapngtool -v 2>/dev/null | grep -q "$REQ_HCXTOOLS_VER_STR"; then
        printf "%b\n" "${RED}Error: hcxtools-custom v$REQ_HCXTOOLS_VER_STR or newer is required.${NC}"
        error=1
    fi

    if ! command -v "$HCXDUMPTOOL_BIN" >/dev/null 2>&1; then
        printf "%b\n" "${RED}Error: hcxdumptool not found at %s${NC}" "$HCXDUMPTOOL_BIN"; error=1
    else
        local version_string
        version_string=$(hcxdumptool -v 2>/dev/null)
        case "$version_string" in
            *6.3.5*|*v21.02.0*)
                ;;
            *)
                printf "%b\n" "${RED}Error: hcxdumptool v6.3.5 or v21.02.0 is required.${NC}"
                error=1
                ;;
        esac
    fi
    
    if [ "$error" -eq 1 ]; then
        printf "%b\n" "${RED}Dependency check failed. Please resolve the issues.${NC}"; exit 1
    fi
    printf "${GREEN}Dependencies verified successfully.${NC}\n"
}

pre_flight_checks() {
    if [ -z "$INTERFACE" ]; then
        printf "${YELLOW}No interface specified.${NC}\n"
        if [ "$INTERACTIVE_MODE" -ne 1 ]; then
            printf "Please enter the network interface to use (e.g., wlan2): "
            read -r INTERFACE
            if [ -z "$INTERFACE" ]; then
                printf "${RED}Interface cannot be empty. Aborting.${NC}\n" >&2
                exit 1
            fi
        fi
    fi

    if ! ip link show "$INTERFACE" >/dev/null 2>&1; then
        printf "${RED}Error: Interface '%s' not found.${NC}\n" "$INTERFACE" >&2; exit 1
    fi
    
    printf "${CYAN}Setting interface '%s' to managed mode...${NC}\n" "$INTERFACE"
    ip link set "$INTERFACE" down
    iw "$INTERFACE" set type managed
    ip link set "$INTERFACE" up
    sleep 1
    printf "${GREEN}Interface ready.${NC}\n"
}

start_capture() {
    local output_file="$1"
    local duration="$2"
    local HCX_CMD="$HCXDUMPTOOL_BIN -i $INTERFACE"
    LAST_CAPTURE_FILE="$output_file"

    if [ "$SURVEY_MODE" -ne 1 ]; then
        HCX_CMD="$HCX_CMD -w \"$output_file\""
    fi
    if [ -n "$CHANNELS" ]; then
        HCX_CMD="$HCX_CMD -c $CHANNELS"
    else
        HCX_CMD="$HCX_CMD -F"
    fi
    if [ -n "$STAY_TIME" ]; then
        HCX_CMD="$HCX_CMD -t $STAY_TIME"
    fi
    if [ -n "$BPF_FILE" ]; then
        if [ -f "$BPF_FILE" ]; then
            HCX_CMD="$HCX_CMD --bpf=\"$BPF_FILE\""
        else
            printf "${YELLOW}Warning: BPF file '%s' not found. Ignoring filter.${NC}\n" "$BPF_FILE"
        fi
    fi
    if [ "$ENABLE_GPS" -eq 1 ]; then
        HCX_CMD="$HCX_CMD --gpsd"
    fi
    if [ "$SURVEY_MODE" -eq 1 ]; then
        HCX_CMD="$HCX_CMD --rcascan=$SURVEY_SCAN_MODE"
    fi
    if [ "$PASSIVE_MODE" -eq 1 ]; then
        HCX_CMD="$HCX_CMD --disable_disassociation"
    fi
    if [ "$ACK_FRAMES" -eq 1 ]; then
        HCX_CMD="$HCX_CMD -A"
    fi
    if [ -n "$TIMEOUT" ]; then HCX_CMD="$HCX_CMD --tot=$TIMEOUT"; fi
    if [ -n "$WATCHDOG_MAX" ]; then HCX_CMD="$HCX_CMD --watchdogmax=$WATCHDOG_MAX"; fi
    if [ -n "$ERROR_MAX" ]; then HCX_CMD="$HCX_CMD --errormax=$ERROR_MAX"; fi
    if [ -n "$EXIT_ON_EAPOL" ]; then HCX_CMD="$HCX_CMD --exitoneapol=$EXIT_ON_EAPOL"; fi
    if [ -n "$ASSOCIATION_MAX" ]; then HCX_CMD="$HCX_CMD --associationmax=$ASSOCIATION_MAX"; fi
    if [ -n "$M2_MAX" ]; then HCX_CMD="$HCX_CMD --m2max=$M2_MAX"; fi
    
    if [ -n "$HCXD_OPTS" ]; then
        HCX_CMD="$HCX_CMD $HCXD_OPTS"
    fi

    case "$HCXD_OPTS" in
        *--rds*) ;;
        *) if [ "$SURVEY_MODE" -eq 0 ] && [ "$PASSIVE_MODE" -eq 0 ]; then HCX_CMD="$HCX_CMD --rds=3"; fi ;;
    esac

    log_message "Executing: $HCX_CMD"
    eval "$HCX_CMD" &
    HCX_PID=$!
    if [ -n "$duration" ]; then
        sleep "$duration"
        if kill -0 "$HCX_PID" 2>/dev/null; then kill "$HCX_PID"; fi
    fi
    wait "$HCX_PID" 2>/dev/null
}

cleanup() {
    trap '' INT TERM
    printf "\n${CYAN}--- Cleaning up ---${NC}\n"

    if [ "$HCX_PID" -ne 0 ] && kill -0 "$HCX_PID" 2>/dev/null; then
        kill "$HCX_PID"
        wait "$HCX_PID" 2>/dev/null
    fi
    
    if [ "$START_TIME" -ne 0 ]; then
        local END_TIME
        END_TIME=$(date +%s)
        local ELAPSED_SECONDS=$((END_TIME - START_TIME))
        local MINUTES=$((ELAPSED_SECONDS / 60))
        local SECONDS=$((ELAPSED_SECONDS % 60))
        printf "  - Total session runtime: %sm %ss.\n" "$MINUTES" "$SECONDS"
    fi

    # --- FIX: Added automatic analysis step ---
    if [ "$SURVEY_MODE" -ne 1 ]; then
        # Check if the analyzer exists and the capture file was created and has data
        if [ -x "$ANALYZER_BIN" ] && [ -n "$LAST_CAPTURE_FILE" ] && [ -s "$LAST_CAPTURE_FILE" ]; then
            printf "\n${CYAN}--- Analyzing Session File ---${NC}\n"
            printf "Running analysis on: %s\n" "$LAST_CAPTURE_FILE"
            "$ANALYZER_BIN" "$LAST_CAPTURE_FILE"
        elif [ -n "$LAST_CAPTURE_FILE" ]; then
            printf "\n${YELLOW}Capture complete. File saved to: %s${NC}\n" "$LAST_CAPTURE_FILE"
            printf "${YELLOW}Analyzer script not found or capture file empty. Skipping analysis.${NC}\n"
        fi
    fi

    # --- FIX: This check now works because RESTORE_INTERFACE is initialized ---
    if [ "$RESTORE_INTERFACE" -eq 1 ]; then
        printf "${CYAN}Restoring interface '%s' to managed mode...${NC}\n" "$INTERFACE"
        ip link set "$INTERFACE" down 2>/dev/null
        iw "$INTERFACE" set type managed 2>/dev/null
        ip link set "$INTERFACE" up 2>/dev/null
    fi

    rm -f "$TEMP_FILE" 2>/dev/null
    log_message "Cleanup finished due to user interrupt."

    # Exit with the standard status code for Ctrl+C (SIGINT)
    exit 130
}
trap cleanup INT TERM

interactive_mode() {
    printf "${CYAN}--- Interactive Mode ---${NC}\n"
    
    printf "Enter the network interface (e.g., wlan2): "
    read -r INTERFACE
    if [ -z "$INTERFACE" ]; then printf "${RED}Interface cannot be empty.${NC}\n"; exit 1; fi

    echo "Select a capture mode:"
    echo "  1) Standard Handshake Hunt"
    echo "  2) Passive Scan"
    echo "  3) Client-Only Stealth Hunt"
    echo "  4) PMKID Priority Hunt"
    echo "  5) Time-Warp FTC Attack"
    printf "Choice [1-5]: "
    read -r mode_choice

    case "$mode_choice" in
        1) ;;
        2) PASSIVE_MODE=1;;
        3) HCXD_OPTS="$HCXD_OPTS --associationmax=0";;
        4) HCXD_OPTS="$HCXD_OPTS --m2max=0";;
        5) HCXD_OPTS="$HCXD_OPTS --ftc";;
        *) printf "${RED}Invalid choice.${NC}\n"; exit 1;;
    esac

    printf "Enter capture duration in seconds (leave empty for no limit): "
    read -r DURATION
}

run_adaptive_hunt() {
    printf "\n%b\n" "${BLUE}--- ⚔️ Starting Adaptive Hunt ---${NC}"
    local survey_duration=30
    local TEMP_DIR="/tmp/adaptive_hunt_$$"
    mkdir -p "$TEMP_DIR"
    trap 'rm -rf "$TEMP_DIR"; trap - INT TERM EXIT' INT TERM EXIT

    local TEMP_SCAN_FILE="$TEMP_DIR/scan_results.txt"
    local TARGET_LIST_FILE="$TEMP_DIR/targets.txt"

    printf "${CYAN}Scanning for active networks for %s seconds...${NC}\n" "$survey_duration"
    "$HCXDUMPTOOL_BIN" -i "$INTERFACE" -F --rcascan=a > "$TEMP_SCAN_FILE" 2>&1 &
    local scan_pid=$!
    sleep "$survey_duration"
    kill "$scan_pid" >/dev/null 2>&1
    wait "$scan_pid" 2>/dev/null

    if [ ! -s "$TEMP_SCAN_FILE" ]; then printf "%b\n" "${RED}No networks were found during the survey.${NC}"; return 1; fi
    
    awk '/->/ { bssid = $1; essid = $3; channel = $4; key = bssid"|"essid"|"channel; count[key]++; } END { for (key in count) { print key; } }' "$TEMP_SCAN_FILE" > "$TARGET_LIST_FILE"

    if [ ! -s "$TARGET_LIST_FILE" ]; then printf "%b\n" "${YELLOW}No scannable networks found.${NC}"; return 1; fi
    
    printf "\n%b\n" "${CYAN}Please select a target network to attack:${NC}"
    local menu_line_count
    menu_line_count=$(wc -l < "$TARGET_LIST_FILE")
    
    cat -n "$TARGET_LIST_FILE" | while IFS="|" read -r num bssid essid channel; do
        printf "  %s) %-18s %-25s (Ch: %s)\n" "$(echo "$num" | tr -d ' ')" "$bssid" "$essid" "$channel"
    done
    
    printf "Enter choice [1-%d]: " "$menu_line_count"
    read -r choice

    case "$choice" in
        ''|*[!0-9]*) printf "%b\n" "${RED}Invalid choice. Aborting.${NC}"; return 1;;
    esac
    if [ "$choice" -lt 1 ] || [ "$choice" -gt "$menu_line_count" ]; then printf "%b\n" "${RED}Invalid choice. Aborting.${NC}"; return 1; fi
    
    local selected_target
    selected_target=$(sed -n "${choice}p" "$TARGET_LIST_FILE")
    local target_bssid
    target_bssid=$(echo "$selected_target" | cut -d'|' -f1)
    local target_channel
    target_channel=$(echo "$selected_target" | cut -d'|' -f3)

    local ts
    ts=$(date +%Y%m%d-%H%M%S)
    local output_file="${OUTPUT_DIR}/session-adaptive-${ts}.pcapng"

    printf "\n%b\n" "${BLUE}Starting targeted hunt on BSSID %s (Channel: %s)...${NC}" "$target_bssid" "$target_channel"
    
    local bpf_string="wlan addr2 $target_bssid"
    local temp_bpf_file="/tmp/hcx_adaptive_filter_$$.bpf"
    if ! "$HCXDUMPTOOL_BIN" --bpfc="$bpf_string" > "$temp_bpf_file"; then
        printf "${RED}Error: Failed to compile BPF for adaptive hunt.${NC}\n" >&2
        return 1
    fi
    
    local CAPTURE_CMD="$HCXDUMPTOOL_BIN -i $INTERFACE -w \"$output_file\" -c $target_channel --bpf=\"$temp_bpf_file\""

    log_message "Executing Adaptive Hunt: $CAPTURE_CMD"
    echo "$output_file" >> "$TEMP_FILE"
    eval "$CAPTURE_CMD" &
    HCX_PID=$!

    if [ -n "$DURATION" ]; then
        sleep "$duration"
        if kill -0 "$HCX_PID" 2>/dev/null; then kill "$HCX_PID"; fi
    fi
    
    wait "$HCX_PID" 2>/dev/null
}

run_main_workflow() {
    if [ "$ADAPTIVE_HUNT" -eq 1 ]; then
        run_adaptive_hunt
        return
    fi
    
    local sanitized_tag=""
    if [ -n "$SESSION_TAG" ]; then
        sanitized_tag=$(echo "$SESSION_TAG" | tr -cd '[:alnum:]_-')
    fi

    if [ "$WARDRIVING_LOOP" -gt 0 ]; then
        log_message "Starting Wardriving Loop with ${WARDRIVING_LOOP}s interval and tag: '${sanitized_tag}'"
        if [ "$QUIET" -eq 0 ]; then printf "${BLUE}--- Starting Wardriving Loop (Interval: %ss) ---${NC}\n" "$WARDRIVING_LOOP"; fi
        local loop_count=1
        while true; do
            local ts
            ts=$(date +%Y%m%d-%H%M%S)
            local filename_base="session"
            if [ -n "$sanitized_tag" ]; then filename_base="${filename_base}-${sanitized_tag}"; fi
            
            local loop_output_file="${OUTPUT_DIR}/${filename_base}-wardrive-${ts}.pcapng"
            if [ "$QUIET" -eq 0 ]; then printf "\n${YELLOW}Starting loop #%s... (File: %s)${NC}\n" "$loop_count" "$(basename "$loop_output_file")"; fi
            start_capture "$loop_output_file" "$WARDRIVING_LOOP"
            loop_count=$((loop_count + 1))
            if [ "$QUIET" -eq 0 ]; then printf "${CYAN}Loop complete. Waiting for next cycle... (Ctrl+C to stop)${NC}\n"; fi
        done
    else
        local ts
        ts=$(date +%Y%m%d-%H%M%S)
        local filename_base="session"
        if [ -n "$sanitized_tag" ]; then filename_base="${filename_base}-${sanitized_tag}"; fi
        
        local output_file="${OUTPUT_DIR}/${filename_base}-single-${ts}.pcapng"
        log_message "Starting single capture with tag: '${sanitized_tag}'"
        printf "${BLUE}Starting capture... (File: %s)${NC}\n" "$(basename "$output_file")"
        start_capture "$output_file" "$DURATION"
    fi
}

#==============================================================================
# SCRIPT EXECUTION
#==============================================================================

main() {
    if [ -z "$1" ]; then
        usage
        exit 0
    fi
    
    while [ $# -gt 0 ]; do
        case "$1" in
            -v|--version) printf "hcxdumptool-launcher v%s\n" "$SCRIPT_VERSION"; exit 0;;
            -h|--help) usage; exit 0;;
            --install) install_script; exit 0;;
            --uninstall) uninstall_script; exit 0;;
            --update) update_script; exit 0;;
            --optimize-performance) optimize_performance; exit 0;;
            --restore-config) restore_performance_config; exit 0;;
            --interactive) INTERACTIVE_MODE=1; shift;;
            --profile) load_profile "$2"; shift 2;;
            -i|--interface) INTERFACE="$2"; shift 2;;
            -c|--channels) CHANNELS="$2"; shift 2;;
            -d|--duration) DURATION="$2"; shift 2;;
            -F) CHANNELS=""; shift;;
            --filter-file) FILTER_FILE="$2"; shift 2;;
            --filter-mode)
                FILTER_MODE="$2"
                if [ "$FILTER_MODE" != "whitelist" ] && [ "$FILTER_MODE" != "blacklist" ]; then
                    printf "${RED}Error: Invalid filter mode. Use 'whitelist' or 'blacklist'.${NC}\n" >&2
                    exit 1
                fi
                shift 2;;
            --oui-file) OUI_FILE="$2"; shift 2;;
            --oui-filter-mode)
                OUI_FILTER_MODE="$2"
                if [ "$OUI_FILTER_MODE" != "whitelist" ] && [ "$OUI_FILTER_MODE" != "blacklist" ]; then
                     printf "${RED}Error: Invalid OUI filter mode. Use 'whitelist' or 'blacklist'.${NC}\n" >&2
                     exit 1
                fi
                shift 2;;
            -t|--stay-time) STAY_TIME="$2"; shift 2;;
            --enable-gps) ENABLE_GPS=1; shift;;
            --hcxd-opts) HCXD_OPTS="$HCXD_OPTS $2"; shift 2;;
            --wardriving-loop) WARDRIVING_LOOP="$2"; shift 2;;
            --hunt-adaptive) ADAPTIVE_HUNT=1; shift;;
            --passive) PASSIVE_MODE=1; shift;;
            --survey)
                SURVEY_MODE=1
                case "$2" in
                    "p") SURVEY_SCAN_MODE="p"; shift 2;;
                    "a") SURVEY_SCAN_MODE="a"; shift 2;;
                    ""|--*) shift;; # No argument provided, use default 'a'
                    *) printf "${RED}Error: Invalid survey mode '%s'. Use 'a' or 'p'.${NC}\n" "$2" >&2; exit 1;;
                esac
                ;;
            --client-only-hunt) HCXD_OPTS="$HCXD_OPTS --associationmax=0"; shift;;
            --pmkid-priority-hunt) HCXD_OPTS="$HCXD_OPTS --m2max=0"; shift;;
            --time-warp-attack) HCXD_OPTS="$HCXD_OPTS --ftc"; shift;;
            --ack-frames) ACK_FRAMES=1; shift;;
            --rds) HCXD_OPTS="$HCXD_OPTS --rds=$2"; shift 2;;
            --timeout) TIMEOUT="$2"; shift 2;;
            --watchdog-max) WATCHDOG_MAX="$2"; shift 2;;
            --error-max) ERROR_MAX="$2"; shift 2;;
            --exit-on-eapol) EXIT_ON_EAPOL="$2"; shift 2;;
            --association-max) ASSOCIATION_MAX="$2"; shift 2;;
            --m2-max) M2_MAX="$2"; shift 2;;
            *)
                printf "${RED}Unknown option: '%s'${NC}\n" "$1" >&2
                usage
                exit 1
                ;;
        esac
    done
    
    log_message "Launcher started."
    if [ -z "$QUIET" ]; then show_banner; fi
    
    dependency_check
    generate_bpf_from_mac_list
    generate_bpf_from_oui_list
    if [ "$INTERACTIVE_MODE" -eq 1 ]; then
        interactive_mode
    fi
    
    pre_flight_checks

    if [ -z "$QUIET" ] && [ "$INTERACTIVE_MODE" -ne 1 ]; then
        printf "${YELLOW}Press Enter to start capture, or Ctrl+C to cancel...${NC}"
        read -r
    fi
    
    >"$TEMP_FILE"
    START_TIME=$(date +%s)
    run_main_workflow
}

main "$@"