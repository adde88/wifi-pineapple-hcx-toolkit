#!/bin/sh
#
# hcxdumptool-launcher - An advanced automation framework for hcxdumptool.
# Version: 4.4.0
# Author: Andreas Nilsen
# Github: https://www.github.com/adde88
#
# This script is designed to work with hcxdumptool-custom v6.3.5 and
# hcxtools-custom v6.2.7 available at:
# https://github.com/adde88/openwrt-useful-tools
#

#--- Script Information and Constants ---#
readonly SCRIPT_VERSION="4.4.0"
readonly EXPECTED_HCXDUMPTOOL_VERSION="6.3.5" # For dependency check
readonly INSTALL_DIR="/etc/hcxtools"
readonly PROFILE_DIR="$INSTALL_DIR/profiles"
readonly BPF_DIR="$INSTALL_DIR/bpf-filters"
readonly LOG_FILE="$INSTALL_DIR/launcher.log"
readonly LOG_MAX_SIZE=1048576 # 1MB
readonly INSTALL_BIN="/usr/bin/hcxdumptool-launcher"
readonly CONFIG_FILE="$INSTALL_DIR/config.conf"
readonly FIRST_RUN_FLAG="$INSTALL_DIR/.installed"
readonly OUI_URL="https://standards-oui.ieee.org/oui.txt"
readonly OUI_FILE_PATH="$HOME/.hcxtools/oui.txt"

#--- Color Codes ---#
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m';
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m';

#--- Default Settings ---#
INTERFACE="wlan2"
CHANNELS=""
DURATION=""
OUTPUT_DIR="/root/hcxdumps"
RUN_AND_CRACK=0
WARDRIVING_LOOP=0
DRY_RUN=0
PROFILE=""
BPF_FILE=""
LURE_WITH_FILE=""
EXPORT_FORMAT="22000"
RDS_MODE=1
STAY_TIME=""
WATCHDOG_TIMER=""
HCXD_OPTS=""
ON_COMPLETE_SCRIPT=""
QUIET=0
INTERACTIVE_MODE=0
AUTO_CHANNELS=0
SESSION_NAME=""
RESTORE_INTERFACE=1
# New Persona/Mode Flags
SURVEY_MODE=0
PASSIVE_MODE=0
ENABLE_GPS=0

#--- Runtime Variables ---#
HCXDUMPTOOL_PID=0
ORIGINAL_INTERFACE_MODE=""

#==============================================================================
# HELPER FUNCTIONS
#==============================================================================

log_message() {
    if [ -f "$LOG_FILE" ]; then
        if [ "$(wc -c <"$LOG_FILE" 2>/dev/null)" -gt "$LOG_MAX_SIZE" ]; then
            mv "$LOG_FILE" "$LOG_FILE.old" 2>/dev/null
        fi
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    fi
}

show_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║      HCX Toolkit v${SCRIPT_VERSION} - The Automation Engine         ║"
    echo "║      Author: Andreas Nilsen (adde88@gmail.com)        ║"
    echo "║      Github: https://www.github.com/adde88            ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${RED}LEGAL WARNING: For authorized security testing only!${NC}"
    echo ""
}

show_full_help() {
    local SCRIPT_CMD
    if [ "$0" = "$INSTALL_BIN" ]; then
        SCRIPT_CMD="hcxdumptool-launcher"
    else
        SCRIPT_CMD="$0"
    fi
    echo
    echo -e "${CYAN}--- Advanced Usage & Examples ---${NC}"
    echo
    echo -e "${MAGENTA}1. Handshake Hunter Mode (PMKID Focus)${NC}"
    echo "   # Runs until the first PMKID is captured, then immediately exits and prepares it for cracking."
    echo "   $SCRIPT_CMD -i wlan2 --hunt-and-exit pmkid --run-and-crack"
    echo
    echo -e "${MAGENTA}2. Lure & Capture Clients${NC}"
    echo "   # Actively baits clients by broadcasting network names from a list, optimized for the Pineapple."
    echo "   $SCRIPT_CMD -i wlan2 --lure-with /path/to/essids.txt --pine-optimize"
    echo
    echo -e "${MAGENTA}3. Robust, Unattended Wardriving Loop with Auto-Analysis${NC}"
    echo "   # Runs silent, 15-minute loops, auto-restarts if the interface hangs, and runs a script on each capture."
    echo "   $SCRIPT_CMD -i wlan2 --wardriving-loop 900 --watchdog 60 -q --on-complete /root/post-capture-analysis.sh"
    echo
    echo -e "${MAGENTA}4. Create a New Profile Interactively${NC}"
    echo "   # Launches a guided setup to create and save a new profile named 'my_audit_profile'."
    echo "   $SCRIPT_CMD --create-profile"
    echo
}

usage() {
    local SCRIPT_CMD
    SCRIPT_CMD=$(basename "$0")
    echo -e "${BLUE}Usage:${NC} $SCRIPT_CMD [OPTIONS]"
    echo
    echo -e "${GREEN}Easy Modes / Personas:${NC}"
    echo "  --survey                 Scan for APs without attacking or saving files."
    echo "  --passive                Listen passively; disable all attack transmissions."
    echo "  --enable-gps             Enable GPSD and embed coordinates into the pcapng file."
    echo
    echo -e "${GREEN}Core Capture Options:${NC}"
    echo "  -i, --interface <iface>  Network interface to use (e.g., wlan2)."
    echo "  -c, --channels <ch>      Comma-separated list of channels (e.g., 1,6,11)."
    echo "  --auto-channels <N>      Auto-scan and select the <N> busiest channels."
    echo
    echo -e "${GREEN}Workflow & Automation:${NC}"
    echo "  --wardriving-loop <sec>  Run in a continuous loop, saving a new file every <sec> seconds."
    echo "  --run-and-crack          Automatically convert capture to hash format after stopping."
    echo "  --interactive            Start a detailed interactive session to configure the capture."
    echo
    echo -e "${GREEN}System & Management:${NC}"
    echo "  --install                Install script to $INSTALL_BIN."
    echo "  --update-oui             Download the latest IEEE OUI list (checks for changes)."
    echo "  --profile <name>         Load a configuration profile."
    echo "  --create-profile         Interactively create a new configuration profile."
    echo "  --dry-run                Show the final command without executing it."
    echo "  -v, --version            Show version of the script."
    echo "  -h, --help               Show this help screen."
}

#==============================================================================
# FEATURE FUNCTIONS
#==============================================================================

update_oui_file() {
    echo -e "${BLUE}--- OUI File Updater ---${NC}"
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        echo -e "${RED}Error: 'curl' or 'wget' is required.${NC}"; exit 1;
    fi
    if ! command -v md5sum >/dev/null 2>&1; then
        echo -e "${RED}Error: 'md5sum' is required for checksum verification.${NC}"; exit 1;
    fi

    local temp_oui_file="/tmp/oui.txt.new"
    local oui_dir
    oui_dir=$(dirname "$OUI_FILE_PATH")
    mkdir -p "$oui_dir"

    echo "Downloading latest OUI list to temporary file for verification..."
    if command -v curl >/dev/null 2>&1; then
        curl --silent -o "$temp_oui_file" "$OUI_URL"
    else
        wget -q -O "$temp_oui_file" "$OUI_URL"
    fi

    if [ ! -s "$temp_oui_file" ]; then
        echo -e "${RED}Error: Failed to download the OUI file.${NC}"; rm -f "$temp_oui_file" 2>/dev/null; exit 1;
    fi

    if [ ! -f "$OUI_FILE_PATH" ]; then
        echo -e "${GREEN}No local OUI file found. Installing new version.${NC}"; mv "$temp_oui_file" "$OUI_FILE_PATH"; exit 0;
    fi

    local local_checksum; local_checksum=$(md5sum "$OUI_FILE_PATH" | awk '{print $1}')
    local remote_checksum; remote_checksum=$(md5sum "$temp_oui_file" | awk '{print $1}')

    if [ "$local_checksum" = "$remote_checksum" ]; then
        echo -e "${GREEN}Your OUI file is already up to date. No changes made.${NC}"
    else
        echo -e "${YELLOW}New OUI version detected. Updating local file.${NC}"; mv "$temp_oui_file" "$OUI_FILE_PATH"; echo -e "${GREEN}OUI file updated successfully.${NC}";
    fi
    rm -f "$temp_oui_file" 2>/dev/null
    exit 0
}

create_profile_interactive() {
    local temp_settings=""
    echo -e "${BLUE}--- Interactive Profile Creator ---${NC}"
    read -r -p "Interface [default: auto]: " val; [ -n "$val" ] && temp_settings="${temp_settings}INTERFACE=\"$val\"\n"
    read -r -p "Channels (1a,6a,11a) [default: all]: " val; [ -n "$val" ] && temp_settings="${temp_settings}CHANNELS=\"$val\"\n"
    read -r -p "Stay Time (seconds) [default: 5]: " val; [ -n "$val" ] && temp_settings="${temp_settings}STAY_TIME=$val\n"
    read -r -p "RDS Mode (0-3) [default: 1]: " val; [ -n "$val" ] && temp_settings="${temp_settings}RDS_MODE=$val\n"
    read -r -p "Advanced hcxdumptool options (e.g., --m2max=1): " val; [ -n "$val" ] && temp_settings="${temp_settings}HCXD_OPTS=\"$val\"\n"
    echo
    read -r -p "Enter a name for this profile (e.g., 'my_stealth_profile'): " profile_name
    if [ -z "$profile_name" ]; then echo -e "${RED}Error: Profile name cannot be empty.${NC}"; return 1; fi
    local profile_path="$PROFILE_DIR/$profile_name.conf"
    if [ -f "$profile_path" ]; then
        read -r -p "Profile '$profile_name' already exists. Overwrite? (y/N) " overwrite
        case "$overwrite" in [yY][eE][sS]|[yY]) ;; *) echo "Aborted."; return;; esac
    fi
    printf "# Profile: %s\n# Created: %s\n%b" "$profile_name" "$(date)" "$temp_settings" > "$profile_path"
    echo -e "${GREEN}Profile saved successfully to: $profile_path${NC}"
}

interactive_mode() {
    echo -e "${BLUE}--- Enhanced Interactive Setup ---${NC}"
    read -r -p "Network interface (current: $INTERFACE): " val
    [ -n "$val" ] && INTERFACE="$val"
    read -r -p "Channels (e.g., 1,6,11) or 'auto' for busiest (current: ${CHANNELS:-all}): " val
    if [ "$val" = "auto" ]; then
        read -r -p "How many busy channels to find? (default: 5): " num_ch
        AUTO_CHANNELS=${num_ch:-5}
    elif [ -n "$val" ]; then
        CHANNELS="$val"
    fi
    read -r -p "Capture duration in seconds (blank for forever): " val
    [ -n "$val" ] && DURATION="$val"
    read -r -p "Wardriving loop in seconds (blank for single run): " val
    [ -n "$val" ] && WARDRIVING_LOOP="$val"
    read -r -p "Auto-convert capture to hash file (y/N)? " val
    case "$val" in [yY][eE][sS]|[yY]) RUN_AND_CRACK=1 ;; esac
    read -r -p "Enable GPS for wardriving (y/N)? " val
    case "$val" in [yY][eE][sS]|[yY]) ENABLE_GPS=1 ;; esac
    echo -e "${GREEN}Configuration complete. Proceeding with the specified settings.${NC}\n"
}

detect_busy_channels() {
    local count=${1:-5}
    echo -e "${CYAN}Scanning for the ${count} busiest channels on $INTERFACE...${NC}"
    local busy_channels
    busy_channels=$(iw dev "$INTERFACE" scan 2>/dev/null | grep 'DS Parameter set: channel' | awk '{print $5}' | sort -n | uniq -c | sort -rn | head -n "$count" | awk '{print $2}' | paste -sd, -)
    if [ -n "$busy_channels" ]; then
        echo -e "${GREEN}Found busiest channels: $busy_channels${NC}"
        CHANNELS="$busy_channels"
    else
        echo -e "${YELLOW}Could not detect active channels. Defaulting to all frequencies.${NC}"
        CHANNELS=""
    fi
}

show_config_summary() {
    [ "$QUIET" -eq 1 ] && return
    echo -e "${BLUE}--- Capture Configuration Summary ---${NC}"
    if [ "$SURVEY_MODE" -eq 1 ]; then
        printf "${YELLOW}%-20s:${NC} %s\n" "Mode" "Network Survey"
        printf "${YELLOW}%-20s:${NC} %s\n" "Interface" "${INTERFACE}"
        return
    fi
    printf "${YELLOW}%-20s:${NC} %s\n" "Interface" "${INTERFACE}"
    if [ "$AUTO_CHANNELS" -gt 0 ]; then
        printf "${YELLOW}%-20s:${NC} %s (%s)\n" "Channels" "${CHANNELS}" "Auto-Detected"
    else
        printf "${YELLOW}%-20s:${NC} %s\n" "Channels" "${CHANNELS:-All Frequencies}"
    fi
    [ "$WARDRIVING_LOOP" -gt 0 ] && printf "${YELLOW}%-20s:${NC} %s seconds\n" "Wardriving Loop" "$WARDRIVING_LOOP"
    [ "$PASSIVE_MODE" -eq 1 ] && printf "${YELLOW}%-20s:${NC} %s\n" "Attack Mode" "Passive"
    [ "$ENABLE_GPS" -eq 1 ] && printf "${YELLOW}%-20s:${NC} %s\n" "GPS" "Enabled"
    [ "$RUN_AND_CRACK" -eq 1 ] && printf "${YELLOW}%-20s:${NC} %s\n" "Auto Convert" "Enabled"
    echo
}

#==============================================================================
# CORE LOGIC FUNCTIONS
#==============================================================================

install_script() {
    echo -e "${BLUE}=== Installing HCX Toolkit Launcher ===${NC}"
    echo "This will install the script to $INSTALL_BIN and copy configuration files."
    read -r -p "Continue with installation? (y/N) " response
    case "$response" in
        [yY][eE][sS]|[yY])
            echo -e "${GREEN}Installing...${NC}"
            mkdir -p "$INSTALL_DIR" "$OUTPUT_DIR" "$PROFILE_DIR" "$BPF_DIR" || { echo -e "${RED}Error: Failed to create directories.${NC}"; exit 1; }
            cp "$0" "$INSTALL_BIN" || { echo -e "${RED}Error: Failed to copy script.${NC}"; exit 1; }
            chmod +x "$INSTALL_BIN"
            touch "$FIRST_RUN_FLAG" "$LOG_FILE"
            echo "$SCRIPT_VERSION" > "$INSTALL_DIR/VERSION"
            echo -e "${GREEN}Installation complete! Run with 'hcxdumptool-launcher'.${NC}"
            ;;
        *) echo "Installation cancelled.";;
    esac
}

load_profile() {
    local profile_name="$1"
    local profile_path="$PROFILE_DIR/$profile_name.conf"
    if [ -f "$profile_path" ]; then
        log_message "Loading profile: $profile_name"
        . "$profile_path"
    else
        echo -e "${RED}Error: Profile '$profile_name' not found at '$profile_path'${NC}"; exit 1;
    fi
}

dependency_check() {
    if ! command -v hcxdumptool >/dev/null 2>&1; then
        echo -e "${RED}Fatal Error: hcxdumptool command not found.${NC}"; exit 1;
    fi

    local hcx_version
    hcx_version=$(hcxdumptool --version 2>&1 | grep -o 'v[0-9.]*')
    if ! echo "$hcx_version" | grep -q "$EXPECTED_HCXDUMPTOOL_VERSION"; then
        echo -e "${YELLOW}--- Dependency Warning ---${NC}"
        echo -e "Your hcxdumptool version (${hcx_version:-unknown}) does not match recommended (v$EXPECTED_HCXDUMPTOOL_VERSION)."
        echo "This may cause errors. Press Enter to continue, or Ctrl+C to abort."
        read -r
    fi

    if [ "$RUN_AND_CRACK" -eq 1 ] && ! command -v hcxpcapngtool >/dev/null 2>&1; then
        echo -e "${RED}Fatal Error: hcxpcapngtool not found (required for --run-and-crack).${NC}"; exit 1;
    fi
}

pre_flight_checks() {
    dependency_check

    if [ -z "$INTERFACE" ]; then echo -e "${RED}Error: No network interface specified.${NC}" >&2; exit 1; fi
    if ! ip link show "$INTERFACE" >/dev/null 2>&1; then echo -e "${RED}Error: Interface '$INTERFACE' not found.${NC}" >&2; exit 1; fi

    if [ ! -d "$OUTPUT_DIR" ] && [ "$SURVEY_MODE" -eq 0 ]; then
        [ "$QUIET" -eq 0 ] && echo -e "${YELLOW}Output directory not found. Creating it at: $OUTPUT_DIR${NC}"
        mkdir -p "$OUTPUT_DIR"
    fi

    if [ "$RESTORE_INTERFACE" -eq 1 ]; then
        ORIGINAL_INTERFACE_MODE=$(iw "$INTERFACE" info 2>/dev/null | grep -m1 type | awk '{print $2}')
    fi

    if [ "$AUTO_CHANNELS" -gt 0 ]; then
        detect_busy_channels "$AUTO_CHANNELS"
    fi

    if [ -z "$SESSION_NAME" ]; then
        SESSION_NAME="session-$(date +%Y%m%d)"
    fi
}

run_and_crack_workflow() {
    local pcap_file="$1"
    if [ ! -s "$pcap_file" ]; then
        log_message "Skipping hash conversion; capture file is empty or missing: $pcap_file"; return
    fi
    local prefix="${pcap_file%.pcapng}"
    if [ "$QUIET" -eq 0 ]; then
        echo -e "${BLUE}--- Post-Capture: Converting to Hashes & Wordlists ---${NC}"
    fi
    if hcxpcapngtool --prefix="$prefix" "$pcap_file" >/dev/null 2>&1 && [ -s "$prefix.22000" ]; then
        echo -e "${GREEN}Successfully created analysis files:${NC}"; ls -1 "$prefix".*
        log_message "Analysis files created for $pcap_file with prefix $prefix"
    else
        echo -e "${YELLOW}No crackable handshakes were found in the capture.${NC}"
        log_message "No hashes extracted from $pcap_file"
        rm -f "$prefix".* 2>/dev/null
    fi
}

run_survey_workflow() {
    local HCX_CMD="hcxdumptool -i $INTERFACE -F --rcascan=active"
    if [ "$DRY_RUN" -eq 1 ]; then
        echo -e "${YELLOW}--- DRY RUN ---${NC}\nCommand: ${CYAN}${HCX_CMD}${NC}"
        return
    fi
    log_message "Executing Survey: $HCX_CMD"
    eval "$HCX_CMD"
}

run_main_workflow() {
    if [ "$WARDRIVING_LOOP" -gt 0 ]; then
        log_message "Starting Wardriving Loop with ${WARDRIVING_LOOP}s interval."
        if [ "$QUIET" -eq 0 ]; then echo -e "${BLUE}--- Starting Wardriving Loop (Interval: ${WARDRIVING_LOOP}s) ---${NC}"; fi
        local loop_count=1
        while true; do
            local ts; ts=$(date +%Y%m%d-%H%M%S)
            local loop_output_file="${OUTPUT_DIR}/${SESSION_NAME}-wardrive-${ts}.pcapng"
            if [ "$QUIET" -eq 0 ]; then echo -e "\n${YELLOW}Starting loop #$loop_count...${NC}"; fi
            start_capture "$loop_output_file" "$WARDRIVING_LOOP"
            if [ "$RUN_AND_CRACK" -eq 1 ]; then run_and_crack_workflow "$loop_output_file"; fi
            if [ -n "$ON_COMPLETE_SCRIPT" ] && [ -x "$ON_COMPLETE_SCRIPT" ]; then
                "$ON_COMPLETE_SCRIPT" "$loop_output_file"
            fi
            loop_count=$((loop_count + 1))
            if [ "$QUIET" -eq 0 ]; then echo -e "${CYAN}Loop complete. Waiting for next cycle... (Ctrl+C to stop)${NC}"; fi
        done
    else
        local ts; ts=$(date +%Y%m%d-%H%M%S)
        local output_file="${OUTPUT_DIR}/${SESSION_NAME}-single-${ts}.pcapng"
        start_capture "$output_file" "$DURATION"
        if [ "$RUN_AND_CRACK" -eq 1 ]; then run_and_crack_workflow "$output_file"; fi
        if [ -n "$ON_COMPLETE_SCRIPT" ] && [ -x "$ON_COMPLETE_SCRIPT" ]; then
            "$ON_COMPLETE_SCRIPT" "$output_file"
        fi
    fi
}

start_capture() {
    local output_file="$1"
    local duration="$2"
    local HCX_CMD="hcxdumptool -i $INTERFACE"
    if [ -z "$output_file" ]; then echo "${RED}Internal Error: Output file not specified.${NC}"; return 1; fi
    HCX_CMD="$HCX_CMD -w \"$output_file\""
    if [ "$RDS_MODE" -ne 0 ]; then HCX_CMD="$HCX_CMD --rds=$RDS_MODE"; fi
    if [ -n "$CHANNELS" ]; then HCX_CMD="$HCX_CMD -c $CHANNELS"; else HCX_CMD="$HCX_CMD -F"; fi
    if [ -n "$STAY_TIME" ]; then HCX_CMD="$HCX_CMD -t $STAY_TIME"; fi
    if [ -n "$BPF_FILE" ] && [ -f "$BPF_FILE" ]; then HCX_CMD="$HCX_CMD --bpf=\"$BPF_FILE\""; fi
    if [ -n "$LURE_WITH_FILE" ] && [ -f "$LURE_WITH_FILE" ]; then HCX_CMD="$HCX_CMD --essidlist=\"$LURE_WITH_FILE\""; fi
    if [ -n "$WATCHDOG_TIMER" ]; then HCX_CMD="$HCX_CMD --watchdogmax=$WATCHDOG_TIMER"; fi
    if [ -n "$HCXD_OPTS" ]; then HCX_CMD="$HCX_CMD $HCXD_OPTS"; fi
    if [ "$DRY_RUN" -eq 1 ]; then
        echo -e "${YELLOW}--- DRY RUN ---${NC}\nCommand: ${CYAN}${HCX_CMD}${NC}"; return
    fi
    if [ "$QUIET" -eq 0 ]; then echo -e "${GREEN}Starting hcxdumptool... (Press Ctrl+C to stop)${NC}"; fi
    log_message "Executing: $HCX_CMD"
    if [ "$QUIET" -eq 1 ]; then eval "$HCX_CMD" >/dev/null 2>&1 &; else eval "$HCX_CMD" &; fi
    HCXDUMPTOOL_PID=$!
    if [ -n "$duration" ]; then
        sleep "$duration"
        if kill -0 "$HCXDUMPTOOL_PID" 2>/dev/null; then
            kill "$HCXDUMPTOOL_PID"
        fi
    fi
    wait "$HCXDUMPTOOL_PID" 2>/dev/null
    log_message "Capture process ended."
    if [ "$QUIET" -eq 0 ]; then echo -e "\n${GREEN}Capture stopped.${NC}"; fi
}

cleanup() {
    if [ "$QUIET" -eq 0 ]; then
        echo -e "\n${CYAN}--- Cleaning up ---${NC}"
    fi
    if [ -n "$HCXDUMPTOOL_PID" ] && kill -0 "$HCXDUMPTOOL_PID" 2>/dev/null; then
        kill "$HCXDUMPTOOL_PID"
    fi
    if [ "$RESTORE_INTERFACE" -eq 1 ] && [ -n "$ORIGINAL_INTERFACE_MODE" ]; then
        ip link set "$INTERFACE" down 2>/dev/null
        iw "$INTERFACE" set type "$ORIGINAL_INTERFACE_MODE" 2>/dev/null
        ip link set "$INTERFACE" up 2>/dev/null
    fi
    log_message "Cleanup finished."
    exit 0
}
trap cleanup INT TERM

#==============================================================================
# SCRIPT EXECUTION
#==============================================================================

if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
fi

if [ $# -eq 0 ] && [ ! -f "$FIRST_RUN_FLAG" ]; then
    show_banner
    install_script
    exit 0
fi

while [ $# -gt 0 ]; do
    case "$1" in
        -v|--version) echo "hcxdumptool-launcher v$SCRIPT_VERSION"; exit 0;;
        -h|--help) usage; exit 0;;
        --install) install_script; exit 0;;
        --update-oui) update_oui_file; exit 0;;
        --profile) if [ -z "$2" ]; then echo -e "${RED}Error: --profile requires a name.${NC}" >&2; exit 1; fi; load_profile "$2"; shift 2;;
        -i|--interface) INTERFACE="$2"; shift 2;;
        -c|--channels) CHANNELS="$2"; shift 2;;
        -o|--output-dir) OUTPUT_DIR="$2"; shift 2;;
        --wardriving-loop) WARDRIVING_LOOP="$2"; shift 2;;
        --hunt-and-exit)
            case "$2" in
                pmkid) HCXD_OPTS="$HCXD_OPTS --exitoneapol=1";;
                full) HCXD_OPTS="$HCXD_OPTS --exitoneapol=2";;
                *) echo -e "${RED}Error: Invalid type for --hunt-and-exit. Use 'pmkid' or 'full'.${NC}" >&2; exit 1;;
            esac
            shift 2;;
        --hcxd-opts) HCXD_OPTS="$HCXD_OPTS $2"; shift 2;;
        --run-and-crack) RUN_AND_CRACK=1; shift;;
        --interactive) INTERACTIVE_MODE=1; shift;;
        --auto-channels) AUTO_CHANNELS=${2:-5}; shift 2;;
        --create-profile) create_profile_interactive; exit 0;;
        --dry-run) DRY_RUN=1; shift;;
        --survey) SURVEY_MODE=1; shift;;
        --passive) PASSIVE_MODE=1; shift;;
        --enable-gps) ENABLE_GPS=1; shift;;
        *) echo -e "${RED}Error: Unknown option '$1'${NC}" >&2; usage; exit 1;;
    esac
done

# --- Main Logic ---
log_message "Launcher started."
if [ "$QUIET" -eq 0 ]; then
    show_banner
fi
if [ "$INTERACTIVE_MODE" -eq 1 ]; then
    interactive_mode
fi
if [ "$PASSIVE_MODE" -eq 1 ]; then
    HCXD_OPTS="$HCXD_OPTS --attemptapmax=0"
fi
if [ "$ENABLE_GPS" -eq 1 ]; then
    HCXD_OPTS="$HCXD_OPTS --gpsd --nmea_pcapng"
fi
if [ "$DRY_RUN" -eq 0 ]; then
    pre_flight_checks
fi
show_config_summary
if [ "$QUIET" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
    echo -e "${YELLOW}Press Enter to start capture, or Ctrl+C to cancel...${NC}"
    read -r
fi
if [ "$SURVEY_MODE" -eq 1 ]; then
    run_survey_workflow
else
    run_main_workflow
fi
cleanup