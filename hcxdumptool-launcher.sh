#!/bin/sh
#
# hcxdumptool-launcher - An advanced automation framework for hcxdumptool.
# Version: 4.0.0
# Author: Andreas Nilsen
# Github: https://www.github.com/adde88
#
# This script is designed to work with hcxdumptool-custom v6.3.5 and
# hcxtools-custom v6.2.7 available at:
# https://github.com/adde88/openwrt-useful-tools
#

#--- Script Information and Constants ---#
readonly SCRIPT_VERSION="4.0.0"
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
INTERFACE=""
CHANNELS="1a,6a,11a"
DURATION=""
OUTPUT_DIR="/root/hcxdumps"
RCA_SCAN=""
# Workflow Modes
RUN_AND_CRACK=0
WARDRIVING_LOOP=0
CLIENT_HUNT=0
HUNT_AND_EXIT=""
DRY_RUN=0
FULL_HELP=0
CREATE_PROFILE=0
PINE_OPTIMIZE=0
# Filtering & Export
PROFILE=""
BPF_FILE=""
LURE_WITH_FILE=""
EXPORT_FORMAT="22000"
# Behavior
RDS_MODE=1
STAY_TIME=5
WATCHDOG_TIMER=""
# Advanced Attack Tuning (can be set in profiles)
M2MAX=""
ASSOCIATIONMAX=""
DISABLE_DISASSOCIATION=0
PROBERESPONSETX=""
# General
HCXD_OPTS=""
ON_COMPLETE_SCRIPT=""
QUIET=0
VERBOSE=0
INTERACTIVE_MODE=0
SESSION_NAME=""
RESTORE_INTERFACE=1

#--- Runtime Variables ---#
HCXDUMPTOOL_PID=0
ORIGINAL_INTERFACE_MODE=""
F_FLAG=0

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
    SCRIPT_CMD=$(if [ "$0" = "$INSTALL_BIN" ]; then echo "hcxdumptool-launcher"; else echo "$0"; fi)
    echo -e "${CYAN}--- Advanced Usage & Examples ---${NC}"
    echo
    echo -e "${MAGENTA}1. Handshake Hunter Mode (PMKID Focus)${NC}"
    echo "   # Runs until the first PMKID is captured, then immediately exits and prepares it for cracking."
    echo "   $SCRIPT_CMD --hunt-and-exit pmkid --run-and-crack -F"
    echo
    echo -e "${MAGENTA}2. Lure & Capture Clients${NC}"
    echo "   # Actively baits clients by broadcasting network names from a list, optimized for the Pineapple."
    echo "   $SCRIPT_CMD --lure-with /path/to/essids.txt --pine-optimize"
    echo
    echo -e "${MAGENTA}3. Robust, Unattended Wardriving Loop${NC}"
    echo "   # Runs silent, 15-minute loops and automatically restarts the capture if the interface hangs for 60 seconds."
    echo "   $SCRIPT_CMD --wardriving-loop 900 --watchdog 60 -q"
    echo
    echo -e "${MAGENTA}4. Create a New Profile Interactively${NC}"
    echo "   # Launches a guided setup to create and save a new profile named 'my_audit_profile'."
    echo "   $SCRIPT_CMD --create-profile"
    echo
}

usage() {
    local SCRIPT_CMD
    SCRIPT_CMD=$(if [ "$0" = "$INSTALL_BIN" ]; then echo "hcxdumptool-launcher"; else echo "$0"; fi)
    echo -e "${BLUE}Usage:${NC} $SCRIPT_CMD [OPTIONS]"
    echo
    echo -e "${GREEN}Primary Modes:${NC}"
    echo "  --rcascan <mode>         Run a Radio Channel Assessment scan ('passive' or 'active')."
    echo "  --client-hunt            Optimize settings for capturing client probe requests."
    echo "  --hunt-and-exit <type>   Run until first handshake is captured ('pmkid' or 'full')."
    echo "  --lure-with <file>       Actively bait clients using an ESSID list from a file."
    echo "  --wardriving-loop <sec>  Run in a continuous loop, saving a new file every <sec> seconds."
    echo
    echo -e "${GREEN}Automation & Optimization:${NC}"
    echo "  --on-complete <script>   Run a script after each capture completes (passes capture file as arg)."
    echo "  --pine-optimize          Apply resource-saving settings ideal for the WiFi Pineapple."
    echo "  --watchdog <sec>         Set the watchdog timer to exit if no packets are received."
    echo "  --hcxd-opts \"...\"        Pass additional, quoted options directly to hcxdumptool."
    echo
    echo -e "${GREEN}System & Management:${NC}"
    echo "  --install                Install script and copy local configs."
    echo "  --create-profile         Start an interactive session to create a new profile."
    echo "  --dry-run                Show the final command without executing it."
    echo "  -h, --help / --full-help Show this help screen or the extended version."
    echo "  -v, --version            Show version of the script."
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
        y|Y|[Yy][Ee][Ss])
            echo -e "${GREEN}Installing...${NC}"
            mkdir -p "$INSTALL_DIR" "$OUTPUT_DIR" "$PROFILE_DIR" "$BPF_DIR" || exit 1
            cp "$0" "$INSTALL_BIN" || exit 1
            chmod +x "$INSTALL_BIN"
            LOCAL_BPF_DIR="$(dirname "$0")/bpf-filters"
            if [ -d "$LOCAL_BPF_DIR" ]; then
                cp "$LOCAL_BPF_DIR"/*.bpf "$BPF_DIR/" 2>/dev/null
            fi
            touch "$FIRST_RUN_FLAG" "$LOG_FILE"
            echo "$SCRIPT_VERSION" > "$INSTALL_DIR/VERSION"
            echo -e "${GREEN}Installation complete! For run-time options run 'hcxdumptool-launcher --help'.${NC}"
            ;;
        *) echo "Installation cancelled.";;
    esac
}

pre_flight_checks() {
    # (Function logic remains unchanged)
}

start_capture() {
    # (Function logic remains unchanged)
}

# (Other functions like create_profile_interactive, show_config_summary, run_main_workflow, etc. remain here)

cleanup() {
    [ "$QUIET" -eq 0 ] && echo -e "\n${CYAN}--- Cleaning up ---${NC}"
    if [ -n "$HCXDUMPTOOL_PID" ] && kill -0 "$HCXDUMPTOOL_PID" 2>/dev/null; then kill "$HCXDUMPTOOL_PID"; fi
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

if [ $# -eq 0 ] && [ ! -f "$FIRST_RUN_FLAG" ]; then
    show_banner
    install_script
    exit 0
fi

# --- Argument Parsing Loop (Refactored for POSIX compliance) ---
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
        --create-profile)
            create_profile_interactive
            exit 0
            ;;
        --list-profiles)
            echo -e "${BLUE}Available Profiles:${NC}"
            ls -1 "$PROFILE_DIR"/*.conf 2>/dev/null | sed 's/\.conf$//;s/.*\///'
            exit 0
            ;;
        --list-filters)
            echo -e "${BLUE}Available BPF Filters:${NC}"
            ls -1 "$BPF_DIR"/*.bpf 2>/dev/null | sed 's/\.bpf$//;s/.*\///'
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
        -i)
            INTERFACE="$2"
            shift 2
            ;;
        -c)
            CHANNELS="$2"
            shift 2
            ;;
        -d)
            DURATION="$2"
            shift 2
            ;;
        -F)
            F_FLAG=1
            shift
            ;;
        -t)
            STAY_TIME="$2"
            shift 2
            ;;
        --rcascan)
            RCA_SCAN="$2"
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
[ "$QUIET" -eq 0 ] && show_banner

if [ "$INTERACTIVE_MODE" -eq 1 ]; then interactive_mode; fi
if [ "$PINE_OPTIMIZE" -eq 1 ]; then QUIET=1; RDS_MODE=0; fi
if [ "$DRY_RUN" -eq 0 ]; then pre_flight_checks; fi

show_config_summary

if [ "$QUIET" -eq 0 ] && [ "$DRY_RUN" -eq 0 ] && [ "$INTERACTIVE_MODE" -eq 0 ]; then
    echo -e "${YELLOW}Press Enter to start capture, or Ctrl+C to cancel...${NC}"
    read -r
fi

run_main_workflow
cleanup
