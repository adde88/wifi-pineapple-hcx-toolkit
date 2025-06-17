#!/bin/sh
#
# hcxdumptool-launcher - An advanced automation framework for hcxdumptool.
# Version: 4.0.9 (Channel Fix)
# Author: Andreas Nilsen
# Github: https://www.github.com/adde88
#
# This script is designed to work with hcxdumptool-custom v6.3.5 and
# hcxtools-custom v6.2.7 available at:
# https://github.com/adde88/openwrt-useful-tools
#

#--- Script Information and Constants ---#
readonly SCRIPT_VERSION="4.0.9"
readonly INSTALL_DIR="/etc/hcxtools"
readonly PROFILE_DIR="$INSTALL_DIR/profiles"
readonly BPF_DIR="$INSTALL_DIR/bpf-filters"
readonly LOG_FILE="$INSTALL_DIR/launcher.log"
readonly LOG_MAX_SIZE=1048576 # 1MB
readonly INSTALL_BIN="/usr/bin/hcxdumptool-launcher"
readonly CONFIG_FILE="$INSTALL_DIR/config.conf"
readonly FIRST_RUN_FLAG="$INSTALL_DIR/.installed"

#--- Color Codes ---#
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m';
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m';

#--- Default Settings ---#
INTERFACE="wlan2"
CHANNELS=""
DURATION=""
OUTPUT_DIR="/root/hcxdumps"
RCA_SCAN=""
RUN_AND_CRACK=0
WARDRIVING_LOOP=0
DRY_RUN=0
PINE_OPTIMIZE=0
FULL_HELP=0
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
SESSION_NAME=""
RESTORE_INTERFACE=1

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
    echo -e "${MAGENTA}3. Robust, Unattended Wardriving Loop${NC}"
    echo "   # Runs silent, 15-minute loops and automatically restarts the capture if the interface hangs for 60 seconds."
    echo "   $SCRIPT_CMD -i wlan2 --wardriving-loop 900 --watchdog 60 -q"
    echo
    echo -e "${MAGENTA}4. Use a Profile for Consistent Settings${NC}"
    echo "   # Assumes 'my_audit.conf' exists in $PROFILE_DIR and sets all options from it."
    echo "   $SCRIPT_CMD --profile my_audit"
    echo
}

usage() {
    local SCRIPT_CMD
    if [ "$0" = "$INSTALL_BIN" ]; then
        SCRIPT_CMD="hcxdumptool-launcher"
    else
        SCRIPT_CMD="$0"
    fi
    echo -e "${BLUE}Usage:${NC} $SCRIPT_CMD [OPTIONS]"
    echo
    echo -e "${GREEN}Core Options:${NC}"
    echo "  -i, --interface <iface>  Network interface to use (e.g., wlan2)."
    echo "  -c, --channels <ch>      Comma-separated list of channels (e.g., 1,6,11). Default: all."
    echo "  -t, --stay-time <sec>    Time in seconds to stay on each channel (may not work with all drivers)."
    echo "  -o, --output-dir <dir>   Directory to save capture files (default: $OUTPUT_DIR)."
    echo
    echo -e "${GREEN}Workflow Modes:${NC}"
    echo "  --wardriving-loop <sec>  Run in a continuous loop, saving a new file every <sec> seconds."
    echo "  --hunt-and-exit <type>   Run until first handshake is captured ('pmkid' or 'full')."
    echo "  --run-and-crack          Automatically convert capture to hash format after stopping."
    echo "  --interactive            Start an interactive session to configure capture."
    echo
    echo -e "${GREEN}System & Management:${NC}"
    echo "  --install                Install script to $INSTALL_BIN."
    echo "  --uninstall              Remove installed script and configuration."
    echo "  --profile <name>         Load a configuration profile from $PROFILE_DIR."
    echo "  --dry-run                Show the final command without executing it."
    echo "  -v, --version            Show version of the script."
    echo "  -h, --help               Show this help screen."
    echo
    if [ "$FULL_HELP" -eq 1 ]; then
        show_full_help
    else
        echo -e "${YELLOW}For advanced options and examples, run: $SCRIPT_CMD --full-help${NC}"
    fi
}

#==============================================================================
# CORE LOGIC FUNCTIONS
#==============================================================================

install_script() {
    echo -e "${BLUE}=== Installing HCX Toolkit Launcher ===${NC}"
    echo "This will install the script to $INSTALL_BIN and copy configuration files."
    read -r -p "Continue with installation? (y/N) " response
    case "$response" in
        y|Y|[Yy][Ee][Ss])
            echo -e "${GREEN}Installing...${NC}"
            mkdir -p "$INSTALL_DIR" "$OUTPUT_DIR" "$PROFILE_DIR" "$BPF_DIR" || { echo -e "${RED}Error: Failed to create directories.${NC}"; exit 1; }
            cp "$0" "$INSTALL_BIN" || { echo -e "${RED}Error: Failed to copy script.${NC}"; exit 1; }
            chmod +x "$INSTALL_BIN"
            LOCAL_BPF_DIR="$(dirname "$0")/bpf-filters"
            if [ -d "$LOCAL_BPF_DIR" ]; then
                cp "$LOCAL_BPF_DIR"/*.bpf "$BPF_DIR/" 2>/dev/null
            fi
            touch "$FIRST_RUN_FLAG" "$LOG_FILE"
            echo "$SCRIPT_VERSION" > "$INSTALL_DIR/VERSION"
            echo -e "${GREEN}Installation complete! Run with 'hcxdumptool-launcher'.${NC}"
            ;;
        *)
            echo "Installation cancelled."
            ;;
    esac
}

load_profile() {
    local profile_name="$1"
    local profile_path="$PROFILE_DIR/$profile_name.conf"
    if [ -f "$profile_path" ]; then
        log_message "Loading profile: $profile_name"
        # shellcheck source=/dev/null
        . "$profile_path"
    else
        echo -e "${RED}Error: Profile '$profile_name' not found at '$profile_path'${NC}"
        exit 1
    fi
}

interactive_mode() {
    echo -e "${BLUE}--- Interactive Setup ---${NC}"
    read -r -p "Enter the network interface (current: $INTERFACE): " new_interface
    if [ -n "$new_interface" ]; then
        INTERFACE="$new_interface"
    fi
    read -r -p "Enter channels (e.g., 1,6,11) or leave blank for all (current: $CHANNELS): " new_channels
    if [ -n "$new_channels" ]; then
        CHANNELS="$new_channels"
    fi
    read -r -p "Enter capture duration in seconds (leave blank to run forever): " new_duration
    if [ -n "$new_duration" ]; then
        DURATION="$new_duration"
    fi
    read -r -p "Automatically convert capture to hash file after stopping? (y/N): " crack_choice
    case "$crack_choice" in
        [yY][eE][sS]|[yY])
            RUN_AND_CRACK=1
            ;;
    esac
    echo -e "${GREEN}Configuration complete. Proceeding with the specified settings.${NC}\n"
}

pre_flight_checks() {
    if ! command -v hcxdumptool >/dev/null 2>&1; then
        echo -e "${RED}Error: hcxdumptool command not found.${NC}"
        exit 1
    fi
    if [ "$RUN_AND_CRACK" -eq 1 ]; then
        if ! command -v hcxpcapngtool >/dev/null 2>&1; then
            echo -e "${RED}Error: hcxpcapngtool command not found (required for --run-and-crack).${NC}"
            exit 1
        fi
    fi
    if [ -z "$INTERFACE" ]; then
        echo -e "${RED}Error: No network interface specified. Use -i <interface>.${NC}" >&2
        exit 1
    fi
    if ! ip link show "$INTERFACE" >/dev/null 2>&1; then
        echo -e "${RED}Error: Interface '$INTERFACE' not found.${NC}" >&2
        exit 1
    fi

    # Ensure the output directory exists before starting
    if [ ! -d "$OUTPUT_DIR" ]; then
        if [ "$QUIET" -eq 0 ]; then
            echo -e "${YELLOW}Output directory not found. Creating it at: $OUTPUT_DIR${NC}"
        fi
        mkdir -p "$OUTPUT_DIR"
    fi

    # Save the original mode before hcxdumptool changes it
    if [ "$RESTORE_INTERFACE" -eq 1 ]; then
        ORIGINAL_INTERFACE_MODE=$(iw "$INTERFACE" info 2>/dev/null | grep -m1 type | awk '{print $2}')
    fi

    if [ -z "$SESSION_NAME" ]; then
        SESSION_NAME="session-$(date +%Y%m%d)"
    fi
}

run_and_crack_workflow() {
    local pcap_file="$1"
    if [ ! -s "$pcap_file" ]; then
        log_message "Skipping hash conversion; capture file is empty or missing: $pcap_file"
        return
    fi
    local hash_file="${pcap_file%.pcapng}.$EXPORT_FORMAT"
    if [ "$QUIET" -eq 0 ]; then
        echo -e "${BLUE}--- Post-Capture: Converting to Hashes (Format: $EXPORT_FORMAT) ---${NC}"
    fi
    if hcxpcapngtool --"$EXPORT_FORMAT"="$hash_file" "$pcap_file" >/dev/null 2>&1 && [ -s "$hash_file" ]; then
        echo -e "${GREEN}Successfully converted to hash file:${NC} $hash_file"
        log_message "Hashes extracted from $pcap_file to $hash_file"
    else
        echo -e "${YELLOW}No crackable handshakes of the desired type were found in the capture.${NC}"
        log_message "No hashes extracted from $pcap_file"
        rm -f "$hash_file" 2>/dev/null
    fi
}

run_main_workflow() {
    if [ "$WARDRIVING_LOOP" -gt 0 ]; then
        log_message "Starting Wardriving Loop with ${WARDRIVING_LOOP}s interval."
        if [ "$QUIET" -eq 0 ]; then
            echo -e "${BLUE}--- Starting Wardriving Loop (Interval: ${WARDRIVING_LOOP}s) ---${NC}"
        fi
        local loop_count=1
        while true; do
            local ts
            ts=$(date +%Y%m%d-%H%M%S)
            local loop_output_file="${OUTPUT_DIR}/${SESSION_NAME}-wardrive-${ts}.pcapng"
            if [ "$QUIET" -eq 0 ]; then
                echo -e "\n${YELLOW}Starting loop #$loop_count...${NC}"
            fi
            start_capture "$loop_output_file" "$WARDRIVING_LOOP"
            if [ "$RUN_AND_CRACK" -eq 1 ]; then
                run_and_crack_workflow "$loop_output_file"
            fi
            if [ -n "$ON_COMPLETE_SCRIPT" ] && [ -x "$ON_COMPLETE_SCRIPT" ]; then
                "$ON_COMPLETE_SCRIPT" "$loop_output_file"
            fi
            loop_count=$((loop_count + 1))
            if [ "$QUIET" -eq 0 ]; then
                echo -e "${CYAN}Loop complete. Waiting for next cycle... (Ctrl+C to stop)${NC}"
            fi
        done
    else
        local ts
        ts=$(date +%Y%m%d-%H%M%S)
        local output_file="${OUTPUT_DIR}/${SESSION_NAME}-single-${ts}.pcapng"
        start_capture "$output_file" "$DURATION"
        if [ "$RUN_AND_CRACK" -eq 1 ]; then
            run_and_crack_workflow "$output_file"
        fi
        if [ -n "$ON_COMPLETE_SCRIPT" ] && [ -x "$ON_COMPLETE_SCRIPT" ]; then
            "$ON_COMPLETE_SCRIPT" "$output_file"
        fi
    fi
}

start_capture() {
    local output_file="$1"
    local duration="$2"
    HCX_CMD="hcxdumptool -i $INTERFACE"
    if [ -n "$STAY_TIME" ]; then
        HCX_CMD="$HCX_CMD -t $STAY_TIME"
    fi
    if [ -n "$RCA_SCAN" ]; then
        HCX_CMD="$HCX_CMD --rcascan=$RCA_SCAN"
    else
        if [ -z "$output_file" ]; then
            echo "${RED}Internal Error: Output file not specified.${NC}"
            return 1
        fi
        HCX_CMD="$HCX_CMD -w \"$output_file\""
        if [ "$RDS_MODE" -ne 0 ]; then
             HCX_CMD="$HCX_CMD --rds=$RDS_MODE"
        fi
    fi
    # Simplified channel logic
    if [ -n "$CHANNELS" ]; then
        HCX_CMD="$HCX_CMD -c $CHANNELS"
    else
        HCX_CMD="$HCX_CMD -F"
    fi
    if [ -n "$BPF_FILE" ] && [ -f "$BPF_FILE" ]; then HCX_CMD="$HCX_CMD --bpf=\"$BPF_FILE\""; fi
    if [ -n "$LURE_WITH_FILE" ] && [ -f "$LURE_WITH_FILE" ]; then HCX_CMD="$HCX_CMD --essidlist=\"$LURE_WITH_FILE\""; fi
    if [ -n "$WATCHDOG_TIMER" ]; then HCX_CMD="$HCX_CMD --watchdogmax=$WATCHDOG_TIMER"; fi
    if [ -n "$HCXD_OPTS" ]; then HCX_CMD="$HCX_CMD $HCXD_OPTS"; fi
    if [ "$DRY_RUN" -eq 1 ]; then
        echo -e "${YELLOW}--- DRY RUN ---${NC}\nCommand: ${CYAN}${HCX_CMD}${NC}"
        return
    fi
    if [ "$QUIET" -eq 0 ]; then
        echo -e "${GREEN}Starting hcxdumptool... (Press Ctrl+C to stop)${NC}"
    fi
    log_message "Executing: $HCX_CMD"
    if [ "$QUIET" -eq 1 ]; then
        eval "$HCX_CMD" >/dev/null 2>&1 &
    else
        eval "$HCX_CMD" &
    fi
    HCXDUMPTOOL_PID=$!
    if [ -n "$duration" ]; then
        sleep "$duration"
        if kill -0 "$HCXDUMPTOOL_PID" 2>/dev/null; then
            kill "$HCXDUMPTOOL_PID"
        fi
    fi
    wait "$HCXDUMPTOOL_PID" 2>/dev/null
    log_message "Capture process ended."
    if [ "$QUIET" -eq 0 ]; then
        echo -e "\n${GREEN}Capture stopped.${NC}"
    fi
}

cleanup() {
    if [ "$QUIET" -eq 0 ]; then
        echo -e "\n${CYAN}--- Cleaning up ---${NC}"
    fi
    if [ -n "$HCXDUMPTOOL_PID" ] && kill -0 "$HCXDUMPTOOL_PID" 2>/dev/null; then
        kill "$HCXDUMPTOOL_PID"
    fi
    if [ "$RESTORE_INTERFACE" -eq 1 ] && [ -n "$ORIGINAL_INTERFACE_MODE" ]; then
        # This will restore the interface to its original state (e.g., managed)
        # after hcxdumptool has finished.
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
        -v|--version)
            echo "Version installed is: v$SCRIPT_VERSION"
            exit 0
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --full-help)
            FULL_HELP=1
            usage
            exit 0
            ;;
        --install)
            install_script
            exit 0
            ;;
        --uninstall)
            rm -rf "$INSTALL_DIR" "$INSTALL_BIN"
            echo "Uninstallation complete."
            exit 0
            ;;
        --list-profiles)
            echo -e "${BLUE}Available Profiles:${NC}"
            ls -1 "$PROFILE_DIR"/*.conf 2>/dev/null | sed 's/\.conf$//' | sed 's/.*\///'
            exit 0
            ;;
        --list-filters)
            echo -e "${BLUE}Available BPF Filters:${NC}"
            ls -1 "$BPF_DIR"/*.bpf 2>/dev/null | sed 's/\.bpf$//' | sed 's/.*\///'
            exit 0
            ;;
        --profile)
            if [ -z "$2" ]; then
                echo -e "${RED}Error: --profile requires a name.${NC}" >&2
                exit 1
            fi
            load_profile "$2"
            shift 2
            ;;
        -i|--interface)
            INTERFACE="$2"
            shift 2
            ;;
        -c|--channels)
            CHANNELS="$2"
            shift 2
            ;;
        -d|--duration)
            DURATION="$2"
            shift 2
            ;;
        -t|--stay-time)
            STAY_TIME="$2"
            shift 2
            ;;
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --rcascan)
            RCA_SCAN="$2"
            shift 2
            ;;
        --wardriving-loop)
            WARDRIVING_LOOP="$2"
            shift 2
            ;;
        --hunt-and-exit)
            if [ "$2" = "pmkid" ]; then
                HCXD_OPTS="$HCXD_OPTS --exitoneapol=1"
            elif [ "$2" = "full" ]; then
                HCXD_OPTS="$HCXD_OPTS --exitoneapol=2"
            else
                echo -e "${RED}Error: Invalid type for --hunt-and-exit. Use 'pmkid' or 'full'.${NC}" >&2
                exit 1
            fi
            shift 2
            ;;
        --lure-with)
            LURE_WITH_FILE="$2"
            shift 2
            ;;
        --watchdog)
            WATCHDOG_TIMER="$2"
            shift 2
            ;;
        --pine-optimize)
            PINE_OPTIMIZE=1
            shift
            ;;
        --on-complete)
            ON_COMPLETE_SCRIPT="$2"
            shift 2
            ;;
        --hcxd-opts)
            HCXD_OPTS="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --interactive)
            INTERACTIVE_MODE=1
            shift
            ;;
        --run-and-crack)
            RUN_AND_CRACK=1
            shift
            ;;
        *)
            echo -e "${RED}Error: Unknown option '$1'${NC}" >&2
            usage
            exit 1
            ;;
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
if [ "$PINE_OPTIMIZE" -eq 1 ]; then
    QUIET=1
    RDS_MODE=0
fi
if [ "$DRY_RUN" -eq 0 ]; then
    pre_flight_checks
fi
if [ "$QUIET" -eq 0 ] && [ "$DRY_RUN" -eq 0 ] && [ "$INTERACTIVE_MODE" -eq 0 ]; then
    echo -e "${YELLOW}Press Enter to start capture, or Ctrl+C to cancel...${NC}"
    read -r
fi

run_main_workflow
cleanup
