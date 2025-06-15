#!/bin/sh
#
# hcxdumptool-launcher - A powerful wrapper for hcxdumptool and hcxtools.
# Version: 3.0.1
# Author: Andreas Nilsen
# Github: https://www.github.com/adde88
#
# This script is designed to work with the custom hcxdumptool & hcxtools packages
# available at: https://github.com/adde88/openwrt-useful-tools
#

#--- Script Information and Constants ---#
readonly SCRIPT_VERSION="3.0.1"
readonly UPDATE_URL="https://raw.githubusercontent.com/adde88/wifi-pineapple-hcx-toolkit/main/hcxdumptool-launcher.sh"
readonly VERSION_URL="https://raw.githubusercontent.com/adde88/wifi-pineapple-hcx-toolkit/main/VERSION"
readonly INSTALL_DIR="/etc/hcxtools"
readonly PROFILE_DIR="$INSTALL_DIR/profiles"
readonly BPF_DIR="$INSTALL_DIR/bpf-filters"
readonly LOG_FILE="$INSTALL_DIR/launcher.log"
readonly LOG_MAX_SIZE=1048576 # 1MB
readonly INSTALL_BIN="/usr/bin/hcxdumptool-launcher"
readonly CONFIG_FILE="$INSTALL_DIR/config.conf"
readonly FIRST_RUN_FLAG="$INSTALL_DIR/.installed"
readonly PKG_DIR="/root/hcx-custom-packages" # Directory for custom .ipk files

#--- Color Codes ---#
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m';
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m';

#--- Default Settings ---#
# Capture
INTERFACE="" # Auto-detect first suitable interface
CHANNELS="1a,6a,11a"
DURATION=""
OUTPUT_DIR="/root/hcxdumps"
RCA_SCAN="" # 'active' or 'passive'
# Workflow Modes
RUN_AND_CRACK=0
WARDRIVING_LOOP=0
CLIENT_HUNT=0
DRY_RUN=0
FULL_HELP=0
# Filtering & Export
PROFILE=""
BPF_FILE=""
EXPORT_FORMAT="22000" # hashcat mode for WPA-PBKDF2-PMKID+EAPOL
# Behavior
RDS_MODE=1
RDS_NO_TIOCGWINSZ=0
STAY_TIME=5
HCXD_OPTS="" # Pass-through options
QUIET=0
VERBOSE=0
INTERACTIVE_MODE=0
# Session & Health
SESSION_NAME=""
# Old features
RESTORE_INTERFACE=1

#--- Runtime Variables ---#
HCXDUMPTOOL_PID=0
ORIGINAL_INTERFACE_MODE=""
F_FLAG=0 # For -F argument

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
    echo "║      HCX Toolkit v${SCRIPT_VERSION} for Custom Packages           ║"
    echo "║      Author: Andreas Nilsen (adde88@gmail.com)        ║"
    echo "║      Github: https://www.github.com/adde88            ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${RED}LEGAL WARNING: For authorized security testing only!${NC}"
    echo ""
}

show_full_help() {
    local SCRIPT_CMD
    SCRIPT_CMD=$(if [ "$0" = "$INSTALL_BIN" ]; then echo "hcxdumptool-launcher"; else echo "$0"; fi)
    echo -e "${CYAN}--- Advanced Usage & Examples ---${NC}"
    echo
    echo -e "${MAGENTA}1. Aggressive PMKID Sweep & Auto-Crack${NC}"
    echo "   # Uses a profile, scans all available frequencies, then converts to hashcat format."
    echo "   $SCRIPT_CMD --profile aggressive -d 600 --run-and-crack -F"
    echo
    echo -e "${MAGENTA}2. Passive RCA Scan on 5GHz Band${NC}"
    echo "   # Passively scans all 5GHz channels to assess the environment without sending packets."
    echo "   $SCRIPT_CMD --rcascan passive -c 36b,40b,44b,48b,149b,153b,157b,161b"
    echo
    echo -e "${MAGENTA}3. Client Hunt with Custom Pass-Through Options${NC}"
    echo "   # Hunts for clients while using advanced hcxdumptool options to exit on the first PMKID."
    echo "   $SCRIPT_CMD --client-hunt --hcxd-opts \"--exitoneapol=1\""
    echo
    echo -e "${MAGENTA}4. Wardriving with Specific Timers${NC}"
    echo "   # Capture in 10-minute loops with a minimum channel stay time of 2s."
    echo "   $SCRIPT_CMD --wardriving-loop 600 -t 2"
    echo
}

usage() {
    local SCRIPT_CMD
    SCRIPT_CMD=$(if [ "$0" = "$INSTALL_BIN" ]; then echo "hcxdumptool-launcher"; else echo "$0"; fi)
    echo -e "${BLUE}Usage:${NC} $SCRIPT_CMD [OPTIONS]"
    echo
    echo -e "${GREEN}Primary Modes:${NC}"
    echo "  --rcascan <mode>         Run a Radio Channel Assessment scan ('passive' or 'active'). No capture file."
    echo "  --client-hunt            Optimize settings for capturing client probe requests."
    echo "  --wardriving-loop <sec>  Run in a continuous loop, saving a new file every <sec> seconds."
    echo
    echo -e "${GREEN}Capture & Channel Options:${NC}"
    echo "  -i <IFACE>               Interface to use. Default: auto-detect."
    echo "  -c <channels>            Channels to scan (e.g., 1a,6a,11a,36b). IMPORTANT: Band is required."
    echo "  -F                       Use all available frequencies from the interface."
    echo "  -t <sec>                 Minimum channel stay time. Default: 5."
    echo
    echo -e "${GREEN}Behavior & Output:${NC}"
    echo "  --rds <mode>             Enable Real Time Display mode. Default: 1."
    echo "  --rdt                    Disable TIOCGWINSZ for real time displays (use with --rds)."
    echo "  --run-and-crack          Automatically convert capture to hashcat format on completion."
    echo "  --export-format <mode>   Set hashcat mode for export (e.g., 22000, 4800, 5500). Default: 22000."
    echo "  --hcxd-opts \"...\"      Pass additional, quoted options directly to hcxdumptool."
    echo
    echo -e "${GREEN}System & Management:${NC}"
    echo "  --install                Install script and copy local configs."
    echo "  --dry-run                Show the final command without executing it."
    echo "  --list-profiles          List all available configuration profiles."
    echo "  --help / --full-help     Show this help screen or the extended version."
    echo
}

#==============================================================================
# CORE LOGIC FUNCTIONS
#==============================================================================

install_script() {
    echo -e "${BLUE}=== Installing HCX Toolkit Launcher ===${NC}"
    echo "This will install the script to $INSTALL_BIN and copy configuration files."
    echo -e "${YELLOW}IMPORTANT: This script requires custom hcxdumptool/hcxtools packages.${NC}"
    echo "Ensure they are installed before proceeding."
    read -r -p "Continue with installation? (y/N) " response
    case "$response" in
        y|Y|yes|YES)
            echo -e "${GREEN}Installing...${NC}"
            mkdir -p "$INSTALL_DIR" "$OUTPUT_DIR" "$PROFILE_DIR" "$BPF_DIR" "$PKG_DIR" || { echo -e "${RED}Error: Failed to create directories.${NC}"; exit 1; }
            cp "$0" "$INSTALL_BIN" || { echo -e "${RED}Error: Failed to copy script.${NC}"; exit 1; }
            chmod +x "$INSTALL_BIN"

            for dir in "bpf-filters" "profiles"; do
                if [ -d "./$dir" ]; then
                    echo "Copying $dir..."
                    cp "./$dir"/* "$INSTALL_DIR/$dir/" 2>/dev/null
                fi
            done
            if ls ./*.ipk >/dev/null 2>&1; then
                echo "Copying custom .ipk packages to $PKG_DIR..."
                cp ./*.ipk "$PKG_DIR/"
            fi

            touch "$FIRST_RUN_FLAG" "$LOG_FILE"
            echo "$SCRIPT_VERSION" > "$INSTALL_DIR/VERSION"
            echo -e "${GREEN}Installation complete! For run-time options run 'hcxdumptool-launcher --help'.${NC}"
            log_message "Script installed/updated successfully to version $SCRIPT_VERSION."
            ;;
        *)
            echo "Installation cancelled."
            ;;
    esac
}

pre_flight_checks() {
    if ! command -v hcxdumptool >/dev/null 2>&1; then echo -e "${RED}Error: hcxdumptool-custom not found. Please install it first.${NC}"; exit 1; fi
    if ! command -v hcxpcapngtool >/dev/null 2>&1; then echo -e "${RED}Error: hcxtools-custom not found. Please install it first.${NC}"; exit 1; fi

    if [ -z "$INTERFACE" ]; then
        INTERFACE=$(hcxdumptool -L 2>/dev/null | head -n 1 | cut -f 1)
        if [ -z "$INTERFACE" ]; then
             echo -e "${RED}Error: Could not auto-detect a suitable wireless interface.${NC}"; exit 1;
        fi
        echo -e "${CYAN}Auto-detected interface: $INTERFACE${NC}"
    fi

    if [ "$(iw "$INTERFACE" info 2>/dev/null | grep type | awk '{print $2}')" = "monitor" ]; then echo -e "${RED}Error: Interface '$INTERFACE' is already in monitor mode.${NC}"; exit 1; fi
    ORIGINAL_INTERFACE_MODE=$(iw "$INTERFACE" info 2>/dev/null | grep type | awk '{print $2}')
    
    if [ "$CLIENT_HUNT" -eq 1 ]; then
        [ "$QUIET" -eq 0 ] && echo -e "${CYAN}Client-Hunt mode enabled: Optimizing for client captures.${NC}"
        BPF_FILE="$BPF_DIR/probe-requests.bpf"
    fi

    if [ -z "$SESSION_NAME" ]; then
        SESSION_NAME="capture-$(date +%Y%m%d)"
    fi
}

start_capture() {
    local output_file="$1"
    local duration="$2"
    
    HCX_CMD="hcxdumptool -i $INTERFACE -t $STAY_TIME"

    if [ -n "$RCA_SCAN" ]; then
        HCX_CMD="$HCX_CMD --rcascan=$RCA_SCAN"
    else
        [ -z "$output_file" ] && { echo "${RED}Internal Error: Output file not specified.${NC}"; return 1; }
        HCX_CMD="$HCX_CMD -w \"$output_file\" --rds=$RDS_MODE"
        [ "$RDS_NO_TIOCGWINSZ" -eq 1 ] && HCX_CMD="$HCX_CMD --rdt"
    fi

    if [ "$F_FLAG" -eq 1 ]; then
        HCX_CMD="$HCX_CMD -F"
    elif [ -n "$CHANNELS" ]; then
        HCX_CMD="$HCX_CMD -c $CHANNELS"
    fi
    
    [ -n "$BPF_FILE" ] && [ -f "$BPF_FILE" ] && HCX_CMD="$HCX_CMD --bpf=\"$BPF_FILE\""
    [ -n "$HCXD_OPTS" ] && HCX_CMD="$HCX_CMD $HCXD_OPTS"

    if [ "$DRY_RUN" -eq 1 ]; then
        echo -e "${YELLOW}--- DRY RUN ---${NC}"
        echo "The following command would be executed:"
        echo -e "${CYAN}${HCX_CMD}${NC}"
        return
    fi

    [ "$QUIET" -eq 0 ] && echo -e "${GREEN}Starting hcxdumptool... (Press Ctrl+C to stop)${NC}"
    log_message "Executing: $HCX_CMD"

    if [ "$QUIET" -eq 1 ]; then
        eval "$HCX_CMD" >/dev/null 2>&1 &
    else
        eval "$HCX_CMD" &
    fi
    HCXDUMPTOOL_PID=$!

    if [ -n "$duration" ]; then sleep "$duration"; if kill -0 "$HCXDUMPTOOL_PID" 2>/dev/null; then kill "$HCXDUMPTOOL_PID"; fi; fi
    wait "$HCXDUMPTOOL_PID" 2>/dev/null
    log_message "Capture process ended."
    [ "$QUIET" -eq 0 ] && echo -e "\n${GREEN}Capture stopped.${NC}"
}

run_and_crack_workflow() {
    local pcap_file="$1"
    if ! [ -s "$pcap_file" ]; then return; fi
    
    local hash_file="${pcap_file%.pcapng}.$EXPORT_FORMAT"
    [ "$QUIET" -eq 0 ] && echo -e "${BLUE}--- Post-Capture: Converting to Hashes ---${NC}"
    
    if hcxpcapngtool -o "$hash_file" "$pcap_file" >/dev/null 2>&1 && [ -s "$hash_file" ]; then
        echo -e "${GREEN}Successfully converted to hash file:${NC} $hash_file"
        echo -e "${YELLOW}Transfer this file to a machine with hashcat for cracking.${NC}"
    else
        echo -e "${YELLOW}No crackable hashes were found in the capture.${NC}"
        rm -f "$hash_file"
    fi
}

run_main_workflow() {
    if [ "$WARDRIVING_LOOP" -gt 0 ]; then
        log_message "Starting Wardriving Loop with ${WARDRIVING_LOOP}s interval."
        [ "$QUIET" -eq 0 ] && echo -e "${BLUE}--- Starting Wardriving Loop (Interval: ${WARDRIVING_LOOP}s) ---${NC}"
        local loop_count=1
        while true; do
            local ts; ts=$(date +%Y%m%d-%H%M%S)
            local loop_output_file="${OUTPUT_DIR}/${SESSION_NAME}-wardrive-${ts}.pcapng"
            [ "$QUIET" -eq 0 ] && echo -e "\n${YELLOW}Starting loop #$loop_count...${NC}"
            start_capture "$loop_output_file" "$WARDRIVING_LOOP"
            if [ "$RUN_AND_CRACK" -eq 1 ]; then run_and_crack_workflow "$loop_output_file"; fi
            loop_count=$((loop_count + 1))
            [ "$QUIET" -eq 0 ] && echo -e "${CYAN}Loop complete. Waiting for next cycle... (Ctrl+C to stop)${NC}"
        done
    else
        local ts; ts=$(date +%Y%m%d-%H%M%S)
        local output_file="${OUTPUT_DIR}/${SESSION_NAME}-single-${ts}.pcapng"
        start_capture "$output_file" "$DURATION"
        if [ "$RUN_AND_CRACK" -eq 1 ]; then run_and_crack_workflow "$output_file"; fi
    fi
}

cleanup() {
    [ "$QUIET" -eq 0 ] && echo -e "\n${CYAN}--- Cleaning up ---${NC}"
    if [ "$HCXDUMPTOOL_PID" -ne 0 ] && kill -0 "$HCXDUMPTOOL_PID" 2>/dev/null; then kill "$HCXDUMPTOOL_PID"; fi
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
[ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"

if [ $# -eq 0 ] && [ ! -f "$FIRST_RUN_FLAG" ]; then show_banner; install_script; exit 0; fi

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help) usage; exit 0;;
        --full-help) FULL_HELP=1; usage; exit 0;;
        --install) install_script; exit 0;;
        -i) INTERFACE="$2"; shift 2;;
        -c) CHANNELS="$2"; shift 2;;
        -F) F_FLAG=1; shift;;
        -t) STAY_TIME="$2"; shift 2;;
        --rcascan) RCA_SCAN="$2"; shift 2;;
        --rds) RDS_MODE="$2"; shift 2;;
        --rdt) RDS_NO_TIOCGWINSZ=1; shift;;
        --hcxd-opts) HCXD_OPTS="$2"; shift 2;;
        --run-and-crack) RUN_AND_CRACK=1; shift;;
        --wardriving-loop) WARDRIVING_LOOP="$2"; shift 2;;
        --client-hunt) CLIENT_HUNT=1; shift;;
        --dry-run) DRY_RUN=1; shift;;
        *) echo "${RED}Unknown option: $1${NC}"; usage; exit 1;;
    esac
done

pre_flight_checks
run_main_workflow
cleanup
