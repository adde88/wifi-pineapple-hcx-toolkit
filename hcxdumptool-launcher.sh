#!/bin/sh
#
# hcxdumptool-launcher - A powerful wrapper for hcxdumptool.
# Version: 2.6.0 (Polished)
# Author: Andreas Nilsen
# Github: https://www.github.com/adde88
# License: GPL-3
#
# IMPORTANT LEGAL NOTICE:
# This tool is for authorized security testing only. Unauthorized access to
# computer networks is illegal. Use responsibly.
#

#--- Script Information and Constants ---#
readonly SCRIPT_VERSION="2.6.0"
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

#--- Color Codes ---#
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m';
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m';

#--- Default Settings ---#
# Capture
INTERFACE="wlan2"
CHANNELS=""
ATTACK_MODE="all"
DURATION=""
OUTPUT_DIR="/root/hcxdumps"
OUTPUT_FILE=""
RCA_SCAN=0
# Workflow Modes
RUN_AND_CRACK=0
WARDRIVING_LOOP=0
CLIENT_HUNT=0
DRY_RUN=0
# Filtering & Export
PROFILE=""
FILTER_FILE=""
FILTER_MODE=""
BPF_FILE=""
EXPORT_FORMAT="hc22000"
# Behavior
RDS_MODE=1
QUIET=0
VERBOSE=0
ENABLE_GPS=0
POWER_SAVE_DISABLE=0
INTERACTIVE_MODE=0
# Session & Health
SESSION_NAME=""
# Old features
RESTORE_INTERFACE=1
AUTO_CHANNELS=0
SCAN_TIME=10

#--- Runtime Variables ---#
HCXDUMPTOOL_PID=0
ORIGINAL_INTERFACE_MODE=""
OPENWRT=$(test -f /etc/openwrt_release && echo 1 || echo 0)

#==============================================================================
# HELPER FUNCTIONS
#==============================================================================

log_rotate() {
    # Rotate log file if it exceeds LOG_MAX_SIZE
    if [ -f "$LOG_FILE" ]; then
        log_size=$(wc -c < "$LOG_FILE" 2>/dev/null)
        if [ "$log_size" -gt "$LOG_MAX_SIZE" ]; then
            mv "$LOG_FILE" "$LOG_FILE.old" 2>/dev/null
            touch "$LOG_FILE"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Log file rotated." >> "$LOG_FILE"
        fi
    fi
}

log_message() {
    # Check for rotation before writing the new message
    log_rotate
    [ -f "$LOG_FILE" ] && echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

show_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║      HCXDumpTool Launcher Script v${SCRIPT_VERSION}               ║"
    echo "║      Author: Andreas Nilsen (adde88@gmail.com)        ║"
    echo "║      Github: https://www.github.com/adde88            ║"
    echo "║      License: GPL-3                                   ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${RED}LEGAL WARNING: Only use on networks you own or have permission to test!${NC}"
    echo ""
}

usage() {
    local SCRIPT_CMD
    SCRIPT_CMD=$(if [ "$0" = "$INSTALL_BIN" ]; then echo "hcxdumptool-launcher"; else echo "$0"; fi)
    echo -e "${BLUE}Usage:${NC} $SCRIPT_CMD [OPTIONS]"
    echo
    echo -e "${GREEN}Workflow Modes:${NC}"
    echo "  --interactive            Start an interactive session to configure capture."
    echo "  --run-and-crack          Automatically convert capture to a hash format."
    echo "  --client-hunt            Optimize settings for capturing client probe requests."
    echo "  --wardriving-loop DURATION  Run in a continuous loop, saving a new file every DURATION seconds."
    echo
    echo -e "${GREEN}System & Management:${NC}"
    echo "  --install                Install script and copy local profiles/filters."
    echo "  --uninstall              Remove installed script and configuration."
    echo "  --check-updates          Check for a new version of the script."
    echo "  --dry-run                Show the final command without executing it."
    echo "  --list-profiles          List all available configuration profiles."
    echo "  --list-filters           List all available BPF filters."
    echo
    echo -e "${GREEN}Other Options:${NC}"
    echo "  -i, --interface IFACE    Network interface (default: $INTERFACE)."
    echo "  -c, --channel CHANNELS   Comma-separated list of channels."
    echo "  --profile NAME           Load a configuration profile from $PROFILE_DIR."
    echo "  --export-format FORMAT   Set output format for --run-and-crack (default: hc22000)."
    echo "  -h, --help               Show this help message."
    echo
}

#==============================================================================
# CORE LOGIC FUNCTIONS
#==============================================================================

install_script() {
    # (Function content remains the same)
    echo -e "${BLUE}=== Installing HCXDumpTool Launcher ===${NC}"
    echo "This will install the script to $INSTALL_BIN and copy configuration files."
    read -r -p "Continue with installation? (y/N) " response
    case "$response" in
        [yY][eE][sS]|[yY])
            echo -e "${GREEN}Installing...${NC}"
            mkdir -p "$INSTALL_DIR" "$OUTPUT_DIR" "$PROFILE_DIR" "$BPF_DIR" || { echo -e "${RED}Error: Failed to create directories.${NC}"; exit 1; }
            cp "$0" "$INSTALL_BIN" || { echo -e "${RED}Error: Failed to copy script.${NC}"; exit 1; }
            chmod +x "$INSTALL_BIN"

            LOCAL_BPF_DIR="$(dirname "$0")/bpf-filters"
            if [ -d "$LOCAL_BPF_DIR" ]; then
                echo "Copying BPF filters..."
                cp "$LOCAL_BPF_DIR"/*.bpf "$BPF_DIR/" 2>/dev/null
            fi

            touch "$FIRST_RUN_FLAG" "$LOG_FILE"
            echo "$SCRIPT_VERSION" > "$INSTALL_DIR/VERSION"
            echo -e "${GREEN}Installation complete! Run with 'hcxdumptool-launcher'.${NC}"
            log_message "Script installed/updated successfully to version $SCRIPT_VERSION."
            ;;
        *) echo "Installation cancelled.";;
    esac
}

load_profile() {
    # (Function content remains the same)
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

pre_flight_checks() {
    # (Function content remains the same)
    if ! command -v hcxdumptool >/dev/null 2>&1; then echo -e "${RED}Error: hcxdumptool not found.${NC}"; exit 1; fi
    if ! ip link show "$INTERFACE" >/dev/null 2>&1; then echo -e "${RED}Error: Interface '$INTERFACE' not found.${NC}"; exit 1; fi
    if [ "$(iw "$INTERFACE" info 2>/dev/null | grep type | awk '{print $2}')" = "monitor" ]; then echo -e "${RED}Error: Interface '$INTERFACE' is already in monitor mode.${NC}"; exit 1; fi
    ORIGINAL_INTERFACE_MODE=$(iw "$INTERFACE" info 2>/dev/null | grep type | awk '{print $2}')
    if [ "$CLIENT_HUNT" -eq 1 ]; then
        [ "$QUIET" -eq 0 ] && echo -e "${CYAN}Client-Hunt mode enabled: Optimizing for client captures.${NC}"
        ATTACK_MODE="client"
        BPF_FILE="$BPF_DIR/probe-requests.bpf"
    fi
    if [ "$AUTO_CHANNELS" -eq 1 ]; then
        CHANNELS=$(detect_busy_channels)
        [ "$QUIET" -eq 0 ] && echo -e "${GREEN}Using auto-detected channels: $CHANNELS${NC}"
    fi
    if [ -z "$SESSION_NAME" ]; then
        SESSION_NAME="capture-$(date +%Y%m%d)"
    fi
}

start_capture() {
    local output_file="$1"
    local duration="$2"
    local HCX_ARGS=("-i" "$INTERFACE")

    if [ "$RCA_SCAN" -eq 1 ]; then
        HCX_ARGS+=("-F" "--rcascan=active")
    else
        [ -z "$output_file" ] && { echo "${RED}Internal Error: Output file not specified.${NC}"; return 1; }
        HCX_ARGS+=("-w" "$output_file" "--rds=$RDS_MODE")
        if [ -z "$CHANNELS" ]; then HCX_ARGS+=("-F"); else HCX_ARGS+=("-c" "$CHANNELS"); fi
        case "$ATTACK_MODE" in
            ap) HCX_ARGS+=("--disable_client_attacks");;
            client) HCX_ARGS+=("--disable_ap_attacks");;
        esac
        [ -n "$BPF_FILE" ] && [ -f "$BPF_FILE" ] && HCX_ARGS+=("--bpf=$BPF_FILE")
    fi

    # Handle --dry-run
    if [ "$DRY_RUN" -eq 1 ]; then
        echo -e "${YELLOW}--- DRY RUN ---${NC}"
        echo "The following command would be executed:"
        echo -e "${CYAN}hcxdumptool ${HCX_ARGS[*]}${NC}"
        return
    fi

    [ "$QUIET" -eq 0 ] && echo -e "${GREEN}Starting hcxdumptool... (Press Ctrl+C to stop)${NC}"
    [ "$VERBOSE" -eq 1 ] && echo "Command: hcxdumptool ${HCX_ARGS[*]}"
    log_message "Executing: hcxdumptool ${HCX_ARGS[*]}"

    hcxdumptool "${HCX_ARGS[@]}" >/dev/null 2>&1 &
    HCXDUMPTOOL_PID=$!

    if [ -n "$duration" ]; then sleep "$duration"; if kill -0 "$HCXDUMPTOOL_PID" 2>/dev/null; then kill "$HCXDUMPTOOL_PID"; fi; fi
    wait "$HCXDUMPTOOL_PID" 2>/dev/null
    log_message "Capture process ended."
    [ "$QUIET" -eq 0 ] && echo -e "\n${GREEN}Capture stopped.${NC}"
}

run_and_crack_workflow() {
    local pcap_file="$1"
    if [ ! -s "$pcap_file" ]; then return; fi
    
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
    # (Function content remains the same)
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
        OUTPUT_FILE="${OUTPUT_DIR}/${SESSION_NAME}-single-${ts}.pcapng"
        start_capture "$OUTPUT_FILE" "$DURATION"
        if [ "$RUN_AND_CRACK" -eq 1 ]; then run_and_crack_workflow "$OUTPUT_FILE"; fi
    fi
}

cleanup() {
    # (Function content remains the same)
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

# --- Load base config ---
[ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"

# --- Argument Parsing ---
if [ $# -eq 0 ] && [ ! -f "$FIRST_RUN_FLAG" ]; then show_banner; install_script; exit 0; fi

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help) usage; exit 0;;
        --install) install_script; exit 0;;
        --uninstall) rm -rf "$INSTALL_DIR" "$INSTALL_BIN"; echo "Uninstallation complete."; exit 0;;
        --list-profiles)
            echo -e "${BLUE}Available Profiles:${NC}"; ls -1 "$PROFILE_DIR"/*.conf 2>/dev/null | sed 's/\.conf$//' | sed 's/.*\///'; exit 0;;
        --list-filters)
            echo -e "${BLUE}Available BPF Filters:${NC}"; ls -1 "$BPF_DIR"/*.bpf 2>/dev/null | sed 's/\.bpf$//' | sed 's/.*\///'; exit 0;;
        --profile) [ -n "$2" ] && load_profile "$2" && shift 2 || { echo "${RED}Error: --profile requires a name.${NC}"; exit 1; };;
        -i|--interface) INTERFACE="$2"; shift 2;;
        -a|--attack-mode) ATTACK_MODE="$2"; shift 2;;
        -c|--channel) CHANNELS="$2"; shift 2;;
        -d|--duration) DURATION="$2"; shift 2;;
        -b|--bpf) BPF_FILE="$2"; shift 2;;
        --export-format) EXPORT_FORMAT="$2"; shift 2;;
        --run-and-crack) RUN_AND_CRACK=1; shift;;
        --wardriving-loop) [ -n "$2" ] && WARDRIVING_LOOP="$2" && shift 2 || { echo "${RED}Error: --wardriving-loop requires a duration.${NC}"; exit 1; };;
        --client-hunt) CLIENT_HUNT=1; shift;;
        --interactive) INTERACTIVE_MODE=1; shift;;
        --rca-scan) RCA_SCAN=1; shift;;
        --dry-run) DRY_RUN=1; shift;;
        -v|--verbose) VERBOSE=1; shift;;
        -q|--quiet) QUIET=1; shift;;
        *) echo "${RED}Unknown option: $1${NC}"; usage; exit 1;;
    esac
done

# --- Main Logic ---
log_message "Launcher started."
[ "$QUIET" -eq 0 ] && show_banner

if [ "$INTERACTIVE_MODE" -eq 1 ]; then interactive_mode; fi

pre_flight_checks
run_main_workflow
cleanup