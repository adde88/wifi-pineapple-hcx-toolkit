#!/bin/sh
#
# hcxdumptool-launcher - An advanced automation framework for hcxdumptool.
# Version: 5.0.1
# Author: Andreas Nilsen
# Github: https://www.github.com/adde88
#
# This script is designed to work with the custom packages from:
# https://github.com/adde88/openwrt-useful-tools

#--- Script Information and Constants ---#
readonly SCRIPT_VERSION="5.0.1"
readonly REQ_HCXDUMPTOOL_VER_STR="v21.02.0"
readonly REQ_HCXTOOLS_VER_STR="6.2.7"
readonly INSTALL_DIR="/etc/hcxtools"
readonly CONFIG_FILE="$INSTALL_DIR/hcxscript.conf"
readonly PROFILE_DIR="$INSTALL_DIR/profiles"
readonly BPF_DIR="$INSTALL_DIR/bpf-filters"
readonly LOG_FILE="$INSTALL_DIR/launcher.log"
readonly INSTALL_BIN="/usr/bin/hcxdumptool-launcher"
readonly ANALYZER_BIN="/usr/bin/hcx-analyzer.sh"
readonly UPDATE_URL="https://raw.githubusercontent.com/adde88/wifi-pineapple-hcx-toolkit/main/hcxdumptool-launcher.sh"

#--- Color Codes ---#
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m';
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

#--- Default Settings ---#
INTERFACE=""
CHANNELS=""
DURATION=""
OUTPUT_DIR="/root/hcxdumps"
RUN_ANALYSIS=""
PROFILE=""
BPF_FILE=""
STAY_TIME=""
HCXD_OPTS=""
QUIET=0
INTERACTIVE_MODE=0
AUTO_CHANNELS=0
SESSION_NAME=""
RESTORE_INTERFACE=1
ENABLE_GPS=0
PASSIVE_MODE=0
SURVEY_MODE=0
HUNT_HANDSHAKES=0
FULL_HELP=0
WARDRIVING_LOOP=0

#--- Runtime Variables ---#
HCXDUMPTOOL_PID=0
TEMP_FILE="/tmp/hcx_session_files_$$"
START_TIME=0

#==============================================================================
# HELPER FUNCTIONS
#==============================================================================

log_message() {
    if [ -f "$LOG_FILE" ] && [ "$(wc -c < "$LOG_FILE" 2>/dev/null)" -gt 1048576 ]; then
        mv "$LOG_FILE" "$LOG_FILE.old" 2>/dev/null
    fi
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

show_banner() {
    echo -e "${CYAN}"
    echo "  _   _  ____  _  _  ____  ____  __  __  _   _ "
    echo " ( )_( )( ___)( )/ )( ___)(  _ \(  )(  )( )_( )"
    echo "  ) _ (  )__)  )  (  )__)  )   / )(__)(  \\   / "
    echo " (_) (_)(____)(_)\_)(____)(_)\_)(______)(_)\_)"
    echo -e "${CYAN}             WiFi Pineapple HCX Toolkit v${SCRIPT_VERSION}${NC}"
    echo -e "${RED}    LEGAL WARNING: For Authorized Security Personnel ONLY!${NC}"
    echo ""
}

show_full_help() {
    local SCRIPT_CMD
    SCRIPT_CMD=$(basename "$0")
    echo
    echo -e "${CYAN}--- Advanced Usage & Examples ---${NC}"
    echo
    echo -e "${BLUE}Simple Examples (Discover & Capture):${NC}"
    echo "  # Passively listen for any client probes on wlan1"
    echo "  $SCRIPT_CMD -i wlan1 --passive --bpf probe-requests"
    echo
    echo "  # Run a quick 5-minute survey for all APs in the area"
    echo "  $SCRIPT_CMD -i wlan1 --survey -d 300"
    echo
    echo -e "${BLUE}Medium Examples (Automation & Targeting):${NC}"
    echo "  # Find the 5 busiest 2.4GHz channels and capture for 10 minutes"
    echo "  $SCRIPT_CMD -i wlan1 --auto-channels 5 -d 600"
    echo
    echo "  # Start a GPS-enabled wardriving session, creating a new file every 15 minutes"
    echo "  $SCRIPT_CMD -i wlan1 --wardriving-loop 900 --enable-gps"
    echo
    echo -e "${BLUE}Advanced Examples (Vulnerability Recon & Analysis):${NC}"
    echo "  # Hunt for handshakes for 10 minutes, then run a deep analysis"
    echo "  $SCRIPT_CMD -i wlan1 --hunt-handshakes -d 600 --analyze vulnerability"
    echo
    echo "  # Load the 'aggressive' profile and add a raw hcxdumptool option for max performance"
    echo "  $SCRIPT_CMD -i wlan1 --profile aggressive --hcxd-opts \"--m2max=10\""
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
    echo "  --hunt-handshakes        Actively deauthenticate clients to capture handshakes."
    echo
    echo -e "${GREEN}Core Capture Options:${NC}"
    echo "  -i, --interface <iface>  Network interface to use."
    echo "  -c, --channels <ch>      Comma-separated list of channels."
    echo "  -d, --duration <sec>     Set capture duration in seconds."
    echo "  -o, --output-dir <dir>   Directory to save capture files."
    echo "  --bpf <filter>           Use a BPF filter by name (e.g., 'eapol-only')."
    echo "  --auto-channels <N>      (STUB) Auto-scan and select the <N> busiest channels."
    echo
    echo -e "${GREEN}Workflow & Automation:${NC}"
    echo "  --wardriving-loop <sec>  Run in a continuous loop."
    echo "  --analyze <mode>         Run analyzer after session (modes: summary, vulnerability, export)."
    echo "  --interactive            Start a guided interactive session."
    echo
    echo -e "${GREEN}System & Management:${NC}"
    echo "  --install                Install script and all components."
    echo "  --uninstall              Remove the toolkit and all related files."
    echo "  --update                 Check for and install updates to the toolkit."
    echo "  --profile <name>         Load a configuration profile."
    echo "  -v, --version            Show script version."
    echo "  -h, --help               Show this help screen."
    echo
    if [ "$FULL_HELP" -eq 1 ]; then
        show_full_help
    else
        echo -e "${YELLOW}For advanced examples, run: $SCRIPT_CMD --full-help${NC}"
    fi
}

#==============================================================================
# CORE LOGIC
#==============================================================================

dependency_check() {
    echo -e "${CYAN}--- Verifying Dependencies ---${NC}"
    local error=0

    if ! command -v hcxdumptool >/dev/null 2>&1; then
        echo -e "${RED}Error: 'hcxdumptool' command not found. Is hcxdumptool-custom installed?${NC}"
        error=1
    elif ! hcxdumptool -v 2>/dev/null | grep -q "$REQ_HCXDUMPTOOL_VER_STR"; then
        echo -e "${RED}Error: 'hcxdumptool' version is incorrect. Required: ~$REQ_HCXDUMPTOOL_VER_STR${NC}"
        error=1
    fi

    if ! command -v hcxpcapngtool >/dev/null 2>&1; then
        echo -e "${RED}Error: 'hcxpcapngtool' command not found. Is hcxtools-custom installed?${NC}"
        error=1
    elif ! hcxpcapngtool -v 2>/dev/null | grep -q "$REQ_HCXTOOLS_VER_STR"; then
        echo -e "${RED}Error: 'hcxpcapngtool' version is incorrect. Required: ~$REQ_HCXTOOLS_VER_STR${NC}"
        error=1
    fi
    
    if [ "$error" -eq 1 ]; then
        echo -e "${RED}Dependency check failed. Please resolve the issues.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Dependencies verified successfully.${NC}"
}

install_script() {
    echo -e "${BLUE}=== Installing HCX Toolkit v${SCRIPT_VERSION} ===${NC}"
    local script_dir
    script_dir=$(dirname "$0")

    dependency_check
    mkdir -p "$INSTALL_DIR" "$OUTPUT_DIR" "$PROFILE_DIR" "$BPF_DIR"
    
    echo "Installing launcher to $INSTALL_BIN..."
    cp "$0" "$INSTALL_BIN" && chmod +x "$INSTALL_BIN"

    if [ -f "$script_dir/hcx-analyzer.sh" ]; then
        echo "Installing analyzer to $ANALYZER_BIN..."
        cp "$script_dir/hcx-analyzer.sh" "$ANALYZER_BIN" && chmod +x "$ANALYZER_BIN"
    fi

    if [ -f "$script_dir/hcxscript.conf" ]; then
        echo "Installing configuration file to $CONFIG_FILE..."
        cp "$script_dir/hcxscript.conf" "$CONFIG_FILE"
    else
        echo -e "${YELLOW}Warning: hcxscript.conf not found. Creating a default one.${NC}"
        cat > "$CONFIG_FILE" << EOF
# Default Configuration for HCX Toolkit
# Settings here are overridden by command-line flags.
# Uncomment lines by removing the '#' to activate them.

# --- Remote Cracking Host Configuration ---
#REMOTE_CRACK_ENABLED=0
#REMOTE_USER="user"
#REMOTE_HOST="192.168.1.100"
#REMOTE_HASHCAT_PATH="/usr/bin/hashcat"
#REMOTE_WORDLIST_PATH="/path/to/your/wordlist.txt"
#REMOTE_CAPTURE_PATH="/home/user/hcx_captures"
EOF
    fi

    echo "$SCRIPT_VERSION" > "$INSTALL_DIR/VERSION"
    touch "$LOG_FILE"
    echo -e "${GREEN}Installation complete! Run 'hcxdumptool-launcher' and 'hcx-analyzer.sh' from anywhere.${NC}"
}

uninstall_script() {
    echo -e "${YELLOW}--- HCX Toolkit Uninstaller ---${NC}"
    echo -e "${RED}WARNING: This will permanently remove the following:${NC}"
    echo " - $INSTALL_BIN"
    echo " - $ANALYZER_BIN"
    echo " - The entire configuration directory: $INSTALL_DIR"
    echo
    printf "Are you sure you want to continue? [y/N] "
    read -r response
    
    case "$response" in
        [yY][eE][sS]|[yY])
            echo "Removing files..."
            rm -f "$INSTALL_BIN" 2>/dev/null
            rm -f "$ANALYZER_BIN" 2>/dev/null
            rm -rf "$INSTALL_DIR" 2>/dev/null
            echo -e "${GREEN}HCX Toolkit has been uninstalled.${NC}"
            ;;
        *)
            echo "Uninstallation cancelled."
            ;;
    esac
}

update_script() {
    echo -e "${BLUE}=== Checking for updates... ===${NC}"
    # --- FIX: Clean up potential newlines and carriage returns from wget output ---
    local remote_version_line
    remote_version_line=$(wget -qO- "$UPDATE_URL" | grep 'readonly SCRIPT_VERSION=')
    REMOTE_VERSION=$(echo "$remote_version_line" | cut -d'"' -f2 | tr -d '\n\r')

    if [ -z "$REMOTE_VERSION" ]; then
        echo -e "${RED}Error: Could not fetch remote version.${NC}"
        exit 1
    fi

    if [ "$REMOTE_VERSION" = "$SCRIPT_VERSION" ]; then
        echo -e "${GREEN}You are already running the latest version ($SCRIPT_VERSION).${NC}"
    else
        echo -e "${YELLOW}A new version ($REMOTE_VERSION) is available. Updating...${NC}"
        wget -qO "$INSTALL_BIN" "$UPDATE_URL" && chmod +x "$INSTALL_BIN"
        echo -e "${GREEN}Update complete!${NC}"
    fi
}

pre_flight_checks() {
    if [ -z "$INTERFACE" ]; then
        echo -e "${YELLOW}No interface specified.${NC}"
        if [ "$INTERACTIVE_MODE" -ne 1 ]; then
            read -r -p "Please enter the network interface to use (e.g., wlan1): " INTERFACE
            if [ -z "$INTERFACE" ]; then
                echo -e "${RED}Interface cannot be empty. Aborting.${NC}" >&2
                exit 1
            fi
        fi
    fi
    
    if ! ip link show "$INTERFACE" >/dev/null 2>&1; then
        echo -e "${RED}Error: Interface '$INTERFACE' not found.${NC}" >&2; exit 1
    fi
    
    echo -e "${CYAN}Setting interface '$INTERFACE' to managed mode...${NC}"
    ip link set "$INTERFACE" down
    iw "$INTERFACE" set type managed
    ip link set "$INTERFACE" up
    sleep 1
    echo -e "${GREEN}Interface ready.${NC}"
}

start_capture() {
    local output_file="$1"
    local duration="$2"
    local HCX_CMD="hcxdumptool -i $INTERFACE"

    if [ "$SURVEY_MODE" -eq 1 ]; then
        HCX_CMD="$HCX_CMD -F --rcascan=a"
    else
        if [ -z "$output_file" ]; then
            echo -e "${RED}Internal Error: Output file not specified for capture.${NC}" >&2
            return 1
        fi
        HCX_CMD="$HCX_CMD -w \"$output_file\""
    fi

    if [ "$HUNT_HANDSHAKES" -eq 1 ]; then
        echo -e "${YELLOW}Handshake hunting enabled (default active attack mode).${NC}"
    fi
    
    if [ "$AUTO_CHANNELS" -gt 0 ]; then
        echo -e "${YELLOW}Warning: --auto-channels is a stub. It is not yet implemented. Using manual channels or -F.${NC}"
    fi
    
    if [ -n "$CHANNELS" ]; then
        HCX_CMD="$HCX_CMD -c $CHANNELS"
    elif [ "$SURVEY_MODE" -ne 1 ]; then
        HCX_CMD="$HCX_CMD -F"
    fi

    if [ -n "$BPF_FILE" ]; then
        if [ -f "$BPF_DIR/$BPF_FILE.bpf" ]; then
            HCX_CMD="$HCX_CMD --bpf=\"$BPF_DIR/$BPF_FILE.bpf\""
        elif [ -f "$BPF_FILE" ]; then
            HCX_CMD="$HCX_CMD --bpf=\"$BPF_FILE\""
        else
             echo -e "${YELLOW}Warning: BPF filter '$BPF_FILE' not found.${NC}"
        fi
    fi

    if [ -n "$STAY_TIME" ]; then
        HCX_CMD="$HCX_CMD -t $STAY_TIME"
    fi
    
    if [ "$PASSIVE_MODE" -eq 1 ]; then
        HCX_CMD="$HCX_CMD --attemptapmax=0"
    fi

    if [ "$ENABLE_GPS" -eq 1 ]; then
        HCX_CMD="$HCX_CMD --gpsd --nmea_pcapng"
    fi

    if [ -n "$HCXD_OPTS" ]; then
        HCX_CMD="$HCX_CMD $HCXD_OPTS"
    fi

    echo "$output_file" >> "$TEMP_FILE"
    
    log_message "Executing: $HCX_CMD"
    eval "$HCX_CMD" &
    HCXDUMPTOOL_PID=$!
    
    if [ -n "$duration" ]; then
        sleep "$duration"
        if kill -0 "$HCXDUMPTOOL_PID" 2>/dev/null; then kill "$HCXDUMPTOOL_PID"; fi
    fi
    
    wait "$HCXDUMPTOOL_PID" 2>/dev/null
    
    if ! kill -0 "$HCXDUMPTOOL_PID" 2>/dev/null; then
        echo -e "${YELLOW}\nProcess finished.${NC}"
    else
        echo -e "${RED}\nError: Process did not terminate cleanly.${NC}"
    fi
}

cleanup() {
    trap '' INT TERM
    if [ "$QUIET" -eq 0 ]; then
        echo -e "\n${CYAN}--- Cleaning up ---${NC}"
    fi
    if [ -n "$HCXDUMPTOOL_PID" ]; then kill "$HCXDUMPTOOL_PID" 2>/dev/null; fi
    
    if [ "$START_TIME" -ne 0 ]; then
        local END_TIME
        END_TIME=$(date +%s)
        local ELAPSED_SECONDS
        ELAPSED_SECONDS=$((END_TIME - START_TIME))
        local MINUTES
        MINUTES=$((ELAPSED_SECONDS / 60))
        local SECONDS
        SECONDS=$((ELAPSED_SECONDS % 60))
        echo -e "  - Total session runtime: ${MINUTES}m ${SECONDS}s."
    fi
    
    local SESSION_FILES
    SESSION_FILES=$(cat "$TEMP_FILE" 2>/dev/null)
    
    if [ "$SURVEY_MODE" -ne 1 ]; then
        if [ -n "$RUN_ANALYSIS" ]; then
            if command -v "$ANALYZER_BIN" >/dev/null 2>&1; then
                echo -e "\n${CYAN}--- Running Post-Scan Analysis (Mode: $RUN_ANALYSIS) ---${NC}"
                "$ANALYZER_BIN" --mode="$RUN_ANALYSIS" "$SESSION_FILES"
            fi
        else
            echo -e "\n${GREEN}Capture complete!${NC}"
            if [ -n "$SESSION_FILES" ]; then
                local hash_count=0
                local temp_hash_output="/tmp/cleanup_hashes.tmp"
                >"$temp_hash_output"
                hcxpcapngtool $SESSION_FILES -o "$temp_hash_output" >/dev/null 2>&1
                if [ -s "$temp_hash_output" ]; then
                    hash_count=$(wc -l < "$temp_hash_output")
                fi
                rm -f "$temp_hash_output"
                
                echo -e "  - ${GREEN}${hash_count}${NC} potential handshakes/PMKIDs extracted."
                echo -e "  - Run '${CYAN}hcx-analyzer.sh${NC}' to perform a full analysis."
            fi
        fi
    fi

    if [ "$RESTORE_INTERFACE" -eq 1 ]; then
        echo -e "${CYAN}Restoring interface '$INTERFACE' to managed mode...${NC}"
        ip link set "$INTERFACE" down 2>/dev/null
        iw "$INTERFACE" set type managed 2>/dev/null
        ip link set "$INTERFACE" up 2>/dev/null
    fi

    rm -f "$TEMP_FILE" 2>/dev/null
    log_message "Cleanup finished."
    exit 0
}
trap cleanup INT TERM

interactive_mode() {
    echo -e "${CYAN}--- Interactive Mode ---${NC}"
    
    read -r -p "Enter the network interface (e.g., wlan1): " INTERFACE
    if [ -z "$INTERFACE" ]; then echo "${RED}Interface cannot be empty.${NC}"; exit 1; fi

    echo "Select a capture mode:"
    echo "  1. Passive Survey (no attacks)"
    echo "  2. Handshake Hunt (active deauth)"
    read -r -p "Choice [1-2]: " mode_choice

    case "$mode_choice" in
        1) SURVEY_MODE=1;;
        2) HUNT_HANDSHAKES=1;;
        *) echo "${RED}Invalid choice.${NC}"; exit 1;;
    esac

    read -r -p "Enter capture duration in seconds (leave empty for no limit): " DURATION
}

run_main_workflow() {
    if [ "$WARDRIVING_LOOP" -gt 0 ]; then
        log_message "Starting Wardriving Loop with ${WARDRIVING_LOOP}s interval."
        if [ "$QUIET" -eq 0 ]; then echo -e "${BLUE}--- Starting Wardriving Loop (Interval: ${WARDRIVING_LOOP}s) ---${NC}"; fi
        local loop_count=1
        while true; do
            local ts
            ts=$(date +%Y%m%d-%H%M%S)
            local loop_output_file="${OUTPUT_DIR}/session-$(date +%Y%m%d)-wardrive-${ts}.pcapng"
            if [ "$QUIET" -eq 0 ]; then echo -e "\n${YELLOW}Starting loop #$loop_count...${NC}"; fi
            start_capture "$loop_output_file" "$WARDRIVING_LOOP"
            loop_count=$((loop_count + 1))
            if [ "$QUIET" -eq 0 ]; then echo -e "${CYAN}Loop complete. Waiting for next cycle... (Ctrl+C to stop)${NC}"; fi
        done
    else
        local ts
        ts=$(date +%Y%m%d-%H%M%S)
        local output_file="${OUTPUT_DIR}/session-$(date +%Y%m%d)-single-${ts}.pcapng"
        start_capture "$output_file" "$DURATION"
    fi
}

#==============================================================================
# SCRIPT EXECUTION
#==============================================================================

main() {
    local has_auto_channels=0
    local has_interface=0
    for arg in "$@"; do
        if [ "$arg" = "--auto-channels" ]; then
            has_auto_channels=1
        fi
        if [ "$arg" = "-i" ] || [ "$arg" = "--interface" ]; then
            has_interface=1
        fi
    done

    if [ "$has_auto_channels" -eq 1 ] && [ "$has_interface" -eq 0 ]; then
        echo -e "${RED}Error: --auto-channels requires a network interface to be specified.${NC}" >&2
        echo "Usage: $0 --auto-channels <N> -i <interface>" >&2
        exit 1
    fi
    
    if [ -f "$CONFIG_FILE" ]; then
        . "$CONFIG_FILE"
    fi

    if [ $# -eq 0 ] && [ ! -f "$INSTALL_BIN" ]; then
        show_banner
        install_script
        exit 0
    fi

    while [ $# -gt 0 ]; do
        case "$1" in
            -v|--version) echo "hcxdumptool-launcher v$SCRIPT_VERSION"; exit 0;;
            -h|--help) usage; exit 0;;
            --full-help) FULL_HELP=1; usage; exit 0;;
            --install) install_script; exit 0;;
            --uninstall) uninstall_script; exit 0;;
            --update) update_script; exit 0;;
            --profile) if [ -z "$2" ]; then echo "${RED}Error: --profile requires a name.${NC}" >&2; exit 1; fi; load_profile "$2"; shift 2;;
            -i|--interface) INTERFACE="$2"; shift 2;;
            -c|--channels) CHANNELS="$2"; shift 2;;
            -d|--duration) DURATION="$2"; shift 2;;
            -o|--output-dir) OUTPUT_DIR="$2"; shift 2;;
            --bpf) BPF_FILE="$2"; shift 2;;
            --stay-time) STAY_TIME="$2"; shift 2;;
            --wardriving-loop) WARDRIVING_LOOP="$2"; shift 2;;
            --hunt-handshakes) HUNT_HANDSHAKES=1; shift;;
            --analyze)
                if [ -z "$2" ] || ! echo "$2" | grep -qE '^(summary|vulnerability|export)$'; then
                    echo -e "${RED}Error: --analyze requires a mode: summary, vulnerability, or export.${NC}" >&2; exit 1
                fi
                RUN_ANALYSIS="$2"; shift 2;;
            --hcxd-opts) HCXD_OPTS="$HCXD_OPTS $2"; shift 2;;
            --interactive) INTERACTIVE_MODE=1; shift;;
            --auto-channels) AUTO_CHANNELS="$2"; shift 2;;
            --survey) SURVEY_MODE=1; shift;;
            --passive) PASSIVE_MODE=1; shift;;
            --enable-gps) ENABLE_GPS=1; shift;;
            *)
                echo -e "${RED}Unknown option: '$1'${NC}" >&2
                usage
                exit 1
                ;;
        esac
    done

    log_message "Launcher started."
    if [ "$QUIET" -eq 0 ]; then
        show_banner
    fi

    dependency_check

    if [ "$INTERACTIVE_MODE" -eq 1 ]; then
        interactive_mode
    fi
    
    pre_flight_checks

    if [ "$QUIET" -eq 0 ]; then
        if [ "$INTERACTIVE_MODE" -ne 1 ]; then
            echo -e "${YELLOW}Press Enter to start capture, or Ctrl+C to cancel...${NC}"
            read -r
        fi
    fi
    >"$TEMP_FILE"
    
    START_TIME=$(date +%s)
    
    run_main_workflow
}

main "$@"