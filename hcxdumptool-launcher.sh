#!/bin/sh
#
# v7.1.0 "Hydra-Intel"
# Author: Andreas Nilsen
# Github: https://www.github.com/ZerBea/hcxtools
#
# This script is designed to work with the custom packages from:
# https://github.com/adde88/openwrt-useful-tools

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
readonly WIRELESS_CONFIG_OPTIMIZED="$INSTALL_DIR/wireless.optimized"
readonly WIRELESS_CONFIG_BACKUP="/etc/config/wireless.hcx-backup"

# --- Dynamically read script version ---
if [ -f "$VERSION_FILE" ]; then
    SCRIPT_VERSION=$(cat "$VERSION_FILE")
else
    SCRIPT_VERSION="7.1.0" # Fallback for standalone execution
fi

# NEW: Sanity check to ensure the version file isn't corrupt.
case "$SCRIPT_VERSION" in
    *[!0-9.]*)
        printf "${RED}Error: The VERSION file at %s is corrupt.${NC}\n" "$VERSION_FILE"
        printf "Please fix it manually. Expected format: X.Y.Z\n"
        exit 1
        ;;
esac

#--- Tool Requirements ---#
readonly REQ_HCXDUMPTOOL_VER_STR="v21.02.0"
readonly REQ_HCXTOOLS_VER_STR="6.2.7"
readonly REQ_HCXLABTOOL_VER_STR="7.0"

#--- Color Codes ---#
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m';
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

#--- Default Settings ---#
INTERFACE=""
CHANNELS=""
DURATION=""
OUTPUT_DIR="/root/hcxdumps"
PROFILE=""
BPF_FILE=""
STAY_TIME=""
HCXD_OPTS=""
QUIET=0
INTERACTIVE_MODE=0
RESTORE_INTERFACE=1
ENABLE_GPS=0
FULL_HELP=0
WARDRIVING_LOOP=0
RDS_MODE=0
FILTER_FILE=""
FILTER_MODE="blacklist"
OUI_FILE=""
OUI_FILTER_MODE="blacklist"

#--- v6.0.0 Settings ---
BACKEND="hcxdumptool" # Default backend
PASSIVE_MODE=0
SURVEY_MODE=0
HUNT_HANDSHAKES=0
CLIENT_ONLY_HUNT=0
PMKID_PRIORITY_HUNT=0
TIME_WARP_ATTACK=0

#--- v7.1.0+ "Hydra-Intel" Settings ---
LIVE_DB_LOG=0
LIVE_LOG_FILE="/tmp/hcx_live_survey.log"

#--- Runtime Variables ---#
HCX_PID=0
TEMP_FILE="/tmp/hcx_session_files_$$"
START_TIME=0

#==============================================================================
# HELPER FUNCTIONS
#==============================================================================

log_message() {
    if [ ! -d "$INSTALL_DIR" ]; then return; fi
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
    echo -e "${BLUE}Use Case 1: Continuous Wardriving with GPS${NC}"
    echo "  # Run a continuous capture, creating a new file every 5 minutes (300s)"
    echo "  # and logging GPS data."
    echo "  $SCRIPT_CMD -i wlan2 --wardriving-loop 300 --enable-gps"
    echo
    echo -e "${BLUE}Use Case 2: Stealthy Client Handshake Hunt${NC}"
    echo "  # Use the hcxlabtool backend to capture client probes without sending deauths."
    echo "  $SCRIPT_CMD -i wlan2 --backend hcxlabtool --client-only-hunt -d 600"
    echo
    echo -e "${BLUE}Use Case 3: Targeted OUI Whitelisting with Time-Warp Attack${NC}"
    echo "  # Focus only on Cisco devices and use the FTC attack to force transitions."
    echo "  $SCRIPT_CMD -i wlan2 --backend hcxlabtool --oui-file cisco.txt --oui-filter-mode whitelist --time-warp-attack"
    echo
    echo -e "${BLUE}Use Case 4: Advanced Real-Time Display${NC}"
    echo "  # Use the advanced Real-Time Display to see PMKID/EAPOL status."
    echo "  $SCRIPT_CMD -i wlan2 --backend hcxlabtool --rds 2"
    echo
    echo -e "${BLUE}Use Case 5: Passing Custom Options${NC}"
    echo "  # Run a standard hunt but pass a custom option to hcxdumptool to disable beacons."
    echo "  $SCRIPT_CMD -i wlan2 --hunt-handshakes --hcxd-opts \"--disable_beacon\""
    echo
}

usage() {
    local SCRIPT_CMD
    SCRIPT_CMD=$(basename "$0")
    echo -e "${BLUE}Usage:${NC} $SCRIPT_CMD -i <interface> [OPTIONS]"
    echo
    echo -e "${GREEN}System & Management:${NC}"
    echo "  -h, --help             Show this basic help screen."
    echo "  --full-help            Show advanced help with examples."
    echo "  -v, --version          Show script version."
    echo "  --install              Install script and all components."
    echo "  --uninstall            Remove the toolkit and all related files."
    echo "  --update               Check for and install updates to the toolkit."
    echo "  --optimize-performance Apply the high-performance wireless configuration."
    echo "  --restore-config       Restore the original wireless configuration."
    echo "  --backend <tool>       Capture engine (hcxdumptool|hcxlabtool). Default: hcxdumptool."
    echo "  --interactive          Start the script in an interactive setup wizard."
    echo "  --profile <name>       Load a configuration profile."
    echo "  --list-profiles        List available configuration profiles."
    echo "  --list-filters         List available BPF filter files."
    echo
    echo -e "${GREEN}Core Capture Options:${NC}"
    echo "  -i, --interface <iface>  [REQUIRED] Specify the wireless interface for capture."
    echo "  -c, --channels <ch>      Set specific channels to scan (e.g., '1,6,11'). Default: All."
    echo "  -d, --duration <secs>    Set the total capture duration in seconds. (Default: unlimited)"
    echo "  -o, --output-dir <path>  Directory to save capture files. Default: /root/hcxdumps."
    echo "  --stay-time <ms>         Time in milliseconds to stay on each channel."
    echo "  --enable-gps             Enable gpsd for logging location data to pcapng file."
    echo
    echo -e "${GREEN}Filtering Options (Mutually Exclusive):${NC}"
    echo "  --bpf <file>             Path to a pre-compiled BPF filter file."
    echo "  --filter-file <file>     Path to a file with full MAC addresses."
    echo "  --filter-mode <mode>     Mode for --filter-file (whitelist|blacklist). Default: blacklist."
    echo "  --oui-file <file>        Path to a file with 3-byte OUIs (e.g., AA:BB:CC)."
    echo "  --oui-filter-mode <mode> Mode for --oui-file (whitelist|blacklist). Default: blacklist."
    echo
    echo -e "${GREEN}Attack & Capture Modes:${NC}"
    echo "  --hunt-handshakes        Actively deauthenticate to capture handshakes (hcxdumptool)."
    echo "  --passive                Run in a strictly passive mode, no deauthentication."
    echo "  --survey                 Perform a network survey without saving capture files."
    echo "  --client-only-hunt       Stealthily capture client handshakes without AP association (hcxlabtool)."
    echo "  --pmkid-priority-hunt    Focus exclusively on capturing PMKIDs from APs (hcxlabtool)."
    echo "  --time-warp-attack       Execute a Forced Transition Candidate (FTC) attack (hcxlabtool)."
    echo "  --wardriving-loop <secs> Run in a continuous loop, creating a new file every N seconds."
    echo "  --live-db-log            Enable live network data logging for advanced DB analysis (hcxlabtool)."
    echo "  --rds <mode>             Set Real-Time Display mode (0=off, 1-3=modes) (hcxlabtool)."
    echo
    echo -e "${GREEN}Advanced Control:${NC}"
    echo "  --hcxd-opts \"<opts>\"     Pass additional, quoted options directly to the backend tool."
    echo
    if [ "$FULL_HELP" -eq 1 ]; then
        show_full_help
    else
        echo -e "${YELLOW}For advanced examples, run: $SCRIPT_CMD --full-help${NC}"
    fi
}

load_profile() {
    local profile_name="$1"
    local profile_path="$PROFILE_DIR/$profile_name.conf"

    if [ ! -f "$profile_path" ]; then
        echo -e "${RED}Error: Profile '$profile_name' not found at '$profile_path'${NC}" >&2
        exit 1
    fi

    echo -e "${CYAN}Loading profile: $profile_name${NC}"
    # shellcheck source=/dev/null
    . "$profile_path"
}

list_profiles() {
    echo -e "${CYAN}--- Available Profiles ---${NC}"
    if [ -d "$PROFILE_DIR" ] && [ -n "$(ls -A "$PROFILE_DIR" 2>/dev/null)" ]; then
        ls -1 "$PROFILE_DIR" | sed 's/\.conf$//'
    else
        echo "No profiles found in $PROFILE_DIR"
    fi
}

list_filters() {
    echo -e "${CYAN}--- Available BPF Filters ---${NC}"
    if [ -d "$BPF_DIR" ] && [ -n "$(ls -A "$BPF_DIR" 2>/dev/null)" ]; then
        ls -1 "$BPF_DIR"
    else
        echo "No BPF filters found in $BPF_DIR"
    fi
}

generate_bpf_from_mac_list() {
    if [ -z "$FILTER_FILE" ]; then return; fi
    if [ ! -f "$FILTER_FILE" ]; then
        echo -e "${RED}Error: Filter file not found at '$FILTER_FILE'${NC}" >&2
        exit 1
    fi

    echo -e "${CYAN}Generating BPF from MAC list: $FILTER_FILE (Mode: $FILTER_MODE)${NC}"
    
    local bpf_string=""
    local mac_list
    mac_list=$(grep -v '^[[:space:]]*#' "$FILTER_FILE" | grep -v '^[[:space:]]*$')

    if [ -z "$mac_list" ]; then
        echo -e "${YELLOW}Warning: Filter file is empty. Ignoring.${NC}"
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
        echo "Successfully created temporary BPF filter."
    else
        echo -e "${RED}Error: Failed to compile BPF from MAC list.${NC}" >&2
        exit 1
    fi
}

generate_bpf_from_oui_list() {
    if [ -z "$OUI_FILE" ]; then return; fi
    if [ ! -f "$OUI_FILE" ]; then
        echo -e "${RED}Error: OUI file not found at '$OUI_FILE'${NC}" >&2
        exit 1
    fi

    echo -e "${CYAN}Generating BPF from OUI list: $OUI_FILE (Mode: $OUI_FILTER_MODE)${NC}"
    
    local bpf_string=""
    local oui_list
    oui_list=$(grep -v '^[[:space:]]*#' "$OUI_FILE" | grep -v '^[[:space:]]*$')

    if [ -z "$oui_list" ]; then
        echo -e "${YELLOW}Warning: OUI file is empty. Ignoring.${NC}"
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
        echo "Successfully created temporary OUI BPF filter."
    else
        echo -e "${RED}Error: Failed to compile BPF from OUI list.${NC}" >&2
        exit 1
    fi
}

#==============================================================================
# CORE LOGIC
#==============================================================================

dependency_check() {
    echo -e "${CYAN}--- Verifying Dependencies ---${NC}"
    local error=0

    if ! command -v hcxpcapngtool >/dev/null 2>&1 || ! hcxpcapngtool -v 2>/dev/null | grep -q "$REQ_HCXTOOLS_VER_STR"; then
        echo -e "${RED}Error: hcxtools-custom v$REQ_HCXTOOLS_VER_STR or newer is required.${NC}"
        error=1
    fi

    if [ "$BACKEND" = "hcxdumptool" ]; then
        if ! command -v hcxdumptool >/dev/null 2>&1 || ! hcxdumptool -v 2>/dev/null | grep -q "$REQ_HCXDUMPTOOL_VER_STR"; then
            echo -e "${RED}Error: hcxdumptool-custom v$REQ_HCXDUMPTOOL_VER_STR or newer is required for this backend.${NC}"
            error=1
        fi
    elif [ "$BACKEND" = "hcxlabtool" ]; then
        if ! command -v hcxlabtool >/dev/null 2>&1 || ! hcxlabtool -v 2>/dev/null | grep -q "$REQ_HCXLABTOOL_VER_STR"; then
            echo -e "${RED}Error: hcxlabtool v$REQ_HCXLABTOOL_VER_STR or newer is required for this backend.${NC}"
            echo -e "${YELLOW}Please install the 'hcxlabtools' package.${NC}"
            error=1
        fi
    fi
    
    if [ "$error" -eq 1 ]; then
        echo -e "${RED}Dependency check failed. Please resolve the issues.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Dependencies verified successfully for backend: $BACKEND${NC}"
}

install_script() {
    echo -e "${BLUE}=== Installing HCX Toolkit v7.0.0 \"Hydra\" ===${NC}"
    local script_dir
    script_dir=$(dirname "$0")

    if ! command -v hcxdumptool >/dev/null 2>&1; then echo -e "${RED}Default package 'hcxdumptool-custom' not found.${NC}"; exit 1; fi
    if ! command -v hcxpcapngtool >/dev/null 2>&1; then echo -e "${RED}Core package 'hcxtools-custom' not found.${NC}"; exit 1; fi

    mkdir -p "$INSTALL_DIR" "$OUTPUT_DIR" "$PROFILE_DIR" "$BPF_DIR"
    
    echo "Installing launcher to $INSTALL_BIN..."
    cp "$0" "$INSTALL_BIN" && chmod +x "$INSTALL_BIN"

    if [ -f "$script_dir/hcx-analyzer.sh" ]; then
        echo "Installing analyzer to $ANALYZER_BIN..."
        cp "$script_dir/hcx-analyzer.sh" "$ANALYZER_BIN" && chmod +x "$ANALYZER_BIN"
    fi

    if [ -d "$script_dir/examples/profiles" ]; then
        echo "Installing example profiles..."
        cp "$script_dir"/examples/profiles/*.conf "$PROFILE_DIR/"
    fi
    if [ -d "$script_dir/bpf-filters" ]; then
        echo "Installing BPF filters..."
        cp "$script_dir"/bpf-filters/*.bpf "$BPF_DIR/"
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

    echo "Creating high-performance wireless config template..."
    cat > "$WIRELESS_CONFIG_OPTIMIZED" << 'EOF'
config wifi-device 'radio0'
    option type 'mac80211'
    option path 'platform/10300000.wmac'
    option band '2g'
    option channel '11'
    option htmode 'HT20'
    option cell_density '0'
    option disabled '0'
    option country 'GY'
    option txpower '30'

config wifi-iface
    option device 'radio0'
    option ifname 'wlan0'
    option network 'lan'
    option mode 'ap'
    option ssid 'Guest'
    option mac '00:C3:C9:44:A7:29'
    option encryption 'owe'
    option isolate '0'
    option wmm '1'
    option hidden '0'
    option disabled '0'
    option disassoc_low_ack '0'
    option beacon_int '50'
    option ap_max_inactivity '300'
    option ieee80211k '1'
    option ieee80211v '1'
    option bss_transition '1'
    option time_advertisement '2'
    option time_zone 'CET-1CEST,M3.5.0,M10.5.0/3'

config wifi-iface
    option device 'radio0'
    option ifname 'wlan0-1'
    option network 'lan'
    option mode 'ap'
    option ssid 'MK7-ADMIN'
    option mac 'AB:09:D0:DD:3B:AA'
    option encryption 'sae-mixed'
    option key 'SETYOURADMINPASSWORDHERE'
    option ieee80211r '1'
    option mobility_domain 'a1b2'
    option hidden '0'
    option isolate '0'
    option wmm '1'
    option disabled '0'
    option disassoc_low_ack '0'
    option beacon_int '50'

config wifi-iface
    option device 'radio0'
    option ifname 'wlan0-2'
    option network 'lan'
    option mode 'ap'
    option ssid 'PineyEnterprise'
    option mac '00:1A:2B:3C:4D:55'
    option encryption 'wpa2+eap'
    option server '127.0.0.1'
    option key 'i_god_damn_love_pineapples'
    option hidden '0'
    option disabled '1'
    option isolate '0'
    option wmm '1'
    option disassoc_low_ack '0'
    option beacon_int '50'

config wifi-iface
    option device 'radio0'
    option ifname 'wlan0-3'
    option network 'lan'
    option mode 'ap'
    option ssid 'TwinAP'
    option mac '74:3A:EF:00:FF:11'
    option encryption 'owe'
    option isolate '0'
    option wmm '1'
    option disabled '0'
    option hidden '0'
    option disassoc_low_ack '0'
    option beacon_int '50'
    option ieee80211k '1'
    option ieee80211v '1'
    option bss_transition '1'

config wifi-device 'radio1'
    option type 'mac80211'
    option path 'platform/101c0000.ehci/usb1/1-1/1-1.1/1-1.1:1.0'
    option band '2g'
    option channel '6'
    option htmode 'HT20'
    option country 'GY'
    option txpower '30'
    option cell_density '0'
    option disabled '0'

config wifi-iface
    option device 'radio1'
    option ifname 'wlan1'
    option mode 'monitor'
    option network 'wan'
    option mac 'A0:AD:9F:00:FE:00'
    option disabled '0'

config wifi-device 'radio2'
    option type 'mac80211'
    option path 'platform/101c0000.ehci/usb1/1-1/1-1.2/1-1.2:1.0'
    option band '2g'
    option channel '1'
    option htmode 'HT20'
    option country 'GY'
    option txpower '30'
    option cell_density '0'
    option disabled '0'
    option country_ie '1'

config wifi-iface
    option device 'radio2'
    option ifname 'wlan2'
    option network 'wcli'
    option mode 'sta'
    option mac 'A0:AD:9F:01:FD:33'
    option disabled '0'
EOF

    echo "7.1.0" > "$VERSION_FILE"
    touch "$LOG_FILE"
    echo -e "${GREEN}Installation complete!${NC}"
    
    echo -e "\n${YELLOW}####################### POST-INSTALL ACTION REQUIRED #######################${NC}"
    echo -e "${CYAN}This toolkit includes a high-performance wireless configuration that can${NC}"
    echo -e "${CYAN}increase capture rates by over 450%%.${NC}"
    echo
    echo -e "To activate it, run the following command:"
    echo -e "${GREEN}hcxdumptool-launcher --optimize-performance${NC}"
    echo
    echo -e "${RED}WARNING:${NC} This will replace your current wireless settings. A backup will"
    echo -e "be created, and you will be given instructions on how to proceed."
    echo -e "${YELLOW}############################################################################${NC}"
}

uninstall_script() {
    echo -e "${YELLOW}--- HCX Toolkit Uninstaller ---${NC}"
    
    if [ -f "$WIRELESS_CONFIG_BACKUP" ]; then
        echo -e "${YELLOW}A backup of your original wireless configuration was found.${NC}"
        printf "Do you want to restore it now? [y/N] "
        read -r restore_response
        if [ "$restore_response" = "y" ] || [ "$restore_response" = "Y" ]; then
            restore_performance_config
        fi
    fi

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
    local remote_version_line
    remote_version_line=$(wget -qO- "$UPDATE_URL" 2>/dev/null | grep 'SCRIPT_VERSION="')
    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Could not download update information. Please check internet connection.${NC}"
        exit 1
    fi
    
    local REMOTE_VERSION
    REMOTE_VERSION=$(echo "$remote_version_line" | cut -d'"' -f2 | tr -d '\n\r')

    # NEW: Sanity check the fetched version number
    case "$REMOTE_VERSION" in
        ""|*[!0-9.]*)
            echo -e "${RED}Error: Could not parse a valid remote version. Got: '$REMOTE_VERSION'${NC}"
            exit 1
            ;;
    esac

    if [ "$REMOTE_VERSION" = "$SCRIPT_VERSION" ]; then
        printf "${GREEN}You are already running the latest version (%s).${NC}\n" "$SCRIPT_VERSION"
    else
        printf "${YELLOW}A new version (%s) is available. Updating...${NC}\n" "$REMOTE_VERSION"
        if wget -qO "$INSTALL_BIN.tmp" "$UPDATE_URL"; then
            mv "$INSTALL_BIN.tmp" "$INSTALL_BIN"
            chmod +x "$INSTALL_BIN"
            echo "$REMOTE_VERSION" > "$VERSION_FILE"
            echo -e "${GREEN}Update complete!${NC}"
        else
            echo -e "${RED}Error: Failed to download the new version.${NC}"
            rm -f "$INSTALL_BIN.tmp"
        fi
    fi
}

optimize_performance() {
    echo -e "${CYAN}--- Applying High-Performance Wireless Configuration ---${NC}"
    if [ ! -f "$WIRELESS_CONFIG_OPTIMIZED" ]; then
        echo -e "${RED}Error: Optimized configuration template not found.${NC}"
        echo "Please run the installer to create it."
        exit 1
    fi
    
    if [ ! -f "$WIRELESS_CONFIG_BACKUP" ]; then
        echo "Backing up current configuration to $WIRELESS_CONFIG_BACKUP..."
        cp /etc/config/wireless "$WIRELESS_CONFIG_BACKUP"
    else
        echo -e "${YELLOW}Backup file already exists. Skipping backup.${NC}"
    fi

    echo "Applying optimized configuration..."
    cp "$WIRELESS_CONFIG_OPTIMIZED" /etc/config/wireless
    
    echo -e "\n${RED}############################################################################${NC}"
    echo -e "${RED}  ACTION REQUIRED: MANUAL CONFIGURATION AND REBOOT NEEDED!${NC}"
    echo -e "${RED}############################################################################${NC}"
    echo -e "${YELLOW}The high-performance wireless configuration has been copied into place.${NC}"
    echo
    echo -e "1. ${RED}!! IMMEDIATE SECURITY RISK !!${NC}"
    echo -e "   The new configuration has a ${YELLOW}DEFAULT PASSWORD${NC} for the 'MK7-ADMIN' network."
    echo -e "   You ${RED}MUST${NC} change this password now."
    echo -e "   - ${CYAN}EDIT THE FILE:${NC} /etc/config/wireless"
    echo -e "   - ${CYAN}FIND THE LINE:${NC} option key 'SETYOURADMINPASSWORDHERE'"
    echo -e "   - ${CYAN}CHANGE THE PASSWORD${NC} to a secure one."
    echo
    echo -e "2. ${YELLOW}!! APPLY CHANGES & REBOOT !!${NC}"
    echo -e "   To ensure these deep hardware changes are applied correctly, you must"
    echo -e "   commit the changes and then ${YELLOW}REBOOT${NC} your device."
    echo
    echo -e "   Run these two commands now:"
    echo -e "   ${GREEN}uci commit wireless${NC}"
    echo -e "   ${GREEN}reboot${NC}"
    echo
    echo -e "To revert these changes at any time, run:"
    echo -e "${CYAN}hcxdumptool-launcher --restore-config${NC}"
    echo -e "${RED}############################################################################${NC}"
}

restore_performance_config() {
    echo -e "${CYAN}--- Restoring Original Wireless Configuration ---${NC}"
    if [ ! -f "$WIRELESS_CONFIG_BACKUP" ]; then
        echo -e "${RED}Error: No backup file found at $WIRELESS_CONFIG_BACKUP.${NC}"
        echo "Cannot restore."
        exit 1
    fi

    echo "Restoring from $WIRELESS_CONFIG_BACKUP..."
    cp "$WIRELESS_CONFIG_BACKUP" /etc/config/wireless

    echo "Committing changes and reloading WiFi..."
    uci commit wireless
    wifi reload

    echo -e "${GREEN}Original wireless configuration has been restored.${NC}"
    echo -e "${YELLOW}A reboot may be required for all changes to take effect.${NC}"
}

pre_flight_checks() {
    if [ -z "$INTERFACE" ]; then
        echo -e "${YELLOW}No interface specified.${NC}"
        if [ "$INTERACTIVE_MODE" -ne 1 ]; then
            read -r -p "Please enter the network interface to use (e.g., wlan2): " INTERFACE
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

    if [ "$LIVE_DB_LOG" -eq 1 ]; then
        if [ "$BACKEND" != "hcxlabtool" ]; then
            echo -e "${YELLOW}Warning: --live-db-log requires the hcxlabtool backend. Overriding.${NC}" >&2
            BACKEND="hcxlabtool"
        fi
        HCXD_OPTS="$HCXD_OPTS --rds=1"
        echo -e "${CYAN}Live DB logging enabled. Survey data will be saved to ${LIVE_LOG_FILE}${NC}"
        rm -f "$LIVE_LOG_FILE"
    fi

    local HCX_CMD="$BACKEND -i $INTERFACE"

    if [ "$SURVEY_MODE" -ne 1 ]; then
        if [ -z "$output_file" ]; then echo -e "${RED}Internal Error: Output file not specified.${NC}" >&2; return 1; fi
        HCX_CMD="$HCX_CMD -w \"$output_file\""
    fi
    if [ -n "$CHANNELS" ]; then HCX_CMD="$HCX_CMD -c $CHANNELS"; else HCX_CMD="$HCX_CMD -F"; fi
    if [ -n "$STAY_TIME" ]; then HCX_CMD="$HCX_CMD -t $STAY_TIME"; fi
    if [ -n "$BPF_FILE" ]; then
        if [ -f "$BPF_FILE" ]; then HCX_CMD="$HCX_CMD --bpf=\"$BPF_FILE\"";
        else echo -e "${YELLOW}Warning: BPF filter '$BPF_FILE' not found.${NC}"; fi
    fi
    if [ "$ENABLE_GPS" -eq 1 ]; then HCX_CMD="$HCX_CMD --gpsd --nmea_pcapng"; fi
    
    if [ "$BACKEND" = "hcxdumptool" ]; then
        if [ "$RDS_MODE" -gt 0 ]; then
             echo -e "${YELLOW}Warning: --rds flag has no effect on the hcxdumptool backend.${NC}"
        fi
        if [ "$SURVEY_MODE" -eq 1 ]; then HCX_CMD="$HCX_CMD --rcascan=a"; fi
        if [ "$PASSIVE_MODE" -eq 1 ]; then HCX_CMD="$HCX_CMD --attemptapmax=0"; fi
    elif [ "$BACKEND" = "hcxlabtool" ]; then
        if [ "$CLIENT_ONLY_HUNT" -eq 1 ]; then HCX_CMD="$HCX_CMD --associationmax=0"; fi
        if [ "$PMKID_PRIORITY_HUNT" -eq 1 ]; then HCX_CMD="$HCX_CMD --m2max=0 --associationmax=100"; fi
        if [ "$TIME_WARP_ATTACK" -eq 1 ]; then HCX_CMD="$HCX_CMD --ftc"; fi
        
        if [ "$LIVE_DB_LOG" -ne 1 ] && [ "$RDS_MODE" -gt 0 ]; then
            HCX_CMD="$HCX_CMD --rds=$RDS_MODE"
        elif [ "$LIVE_DB_LOG" -ne 1 ]; then
             HCX_CMD="$HCX_CMD --rds=3"
        fi
    fi

    if [ -n "$HCXD_OPTS" ]; then HCX_CMD="$HCX_CMD $HCXD_OPTS"; fi

    echo "$output_file" >> "$TEMP_FILE"
    log_message "Executing: $HCX_CMD"
    
    if [ "$LIVE_DB_LOG" -eq 1 ]; then
        eval "$HCX_CMD" > "$LIVE_LOG_FILE" 2>&1 &
    else
        eval "$HCX_CMD" &
    fi

    HCX_PID=$!
    
    if [ -n "$duration" ]; then
        sleep "$duration"
        if kill -0 "$HCX_PID" 2>/dev/null; then kill "$HCX_PID"; fi
    fi
    
    wait "$HCX_PID" 2>/dev/null
    
    if ! kill -0 "$HCX_PID" 2>/dev/null; then echo -e "${YELLOW}\nProcess finished.${NC}";
    else echo -e "${RED}\nError: Process did not terminate cleanly.${NC}"; fi
}

cleanup() {
    trap '' INT TERM
    if [ "$QUIET" -eq 0 ]; then
        echo -e "\n${CYAN}--- Cleaning up ---${NC}"
    fi
    if [ -n "$HCX_PID" ]; then kill "$HCX_PID" 2>/dev/null; fi
    
    if [ "$START_TIME" -ne 0 ]; then
        local END_TIME
        END_TIME=$(date +%s)
        local ELAPSED_SECONDS=$((END_TIME - START_TIME))
        local MINUTES=$((ELAPSED_SECONDS / 60))
        local SECONDS=$((ELAPSED_SECONDS % 60))
        echo -e "  - Total session runtime: ${MINUTES}m ${SECONDS}s."
    fi
    
    if [ "$SURVEY_MODE" -ne 1 ]; then
        echo -e "\n${GREEN}Capture complete!${NC}"
        echo -e "  - Run '${CYAN}hcx-analyzer.sh${NC}' to perform a full analysis."
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
    
    read -r -p "Enter the network interface (e.g., wlan2): " INTERFACE
    if [ -z "$INTERFACE" ]; then echo "${RED}Interface cannot be empty.${NC}"; exit 1; fi

    echo "Select a capture mode:"
    echo "  1) Standard Handshake Hunt (hcxdumptool)"
    echo "  2) Passive Scan (hcxdumptool)"
    echo "  3) Client-Only Stealth Hunt (hcxlabtool)"
    echo "  4) PMKID Priority Hunt (hcxlabtool)"
    echo "  5) Live DB Logging Hunt (hcxlabtool)"
    printf "Choice [1-5]: "
    read -r mode_choice

    case "$mode_choice" in
        1) HUNT_HANDSHAKES=1; BACKEND="hcxdumptool";;
        2) PASSIVE_MODE=1; BACKEND="hcxdumptool";;
        3) CLIENT_ONLY_HUNT=1; BACKEND="hcxlabtool";;
        4) PMKID_PRIORITY_HUNT=1; BACKEND="hcxlabtool";;
        5) LIVE_DB_LOG=1; BACKEND="hcxlabtool";;
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
    if [ "$(basename "$0")" != "hcxdumptool-launcher" ] && [ ! -f "$INSTALL_BIN" ]; then
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
            --optimize-performance) optimize_performance; exit 0;;
            --restore-config) restore_performance_config; exit 0;;
            --list-profiles) list_profiles; exit 0;;
            --list-filters) list_filters; exit 0;;
            --profile) load_profile "$2"; shift 2;;
            -i|--interface) INTERFACE="$2"; shift 2;;
            -c|--channels) CHANNELS="$2"; shift 2;;
            -d|--duration) DURATION="$2"; shift 2;;
            -o|--output-dir) OUTPUT_DIR="$2"; shift 2;;
            --bpf) BPF_FILE="$2"; shift 2;;
            --filter-file) FILTER_FILE="$2"; shift 2;;
            --filter-mode)
                FILTER_MODE="$2"
                if [ "$FILTER_MODE" != "whitelist" ] && [ "$FILTER_MODE" != "blacklist" ]; then
                    echo -e "${RED}Error: Invalid filter mode '$FILTER_MODE'. Use 'whitelist' or 'blacklist'.${NC}" >&2
                    exit 1
                fi
                shift 2;;
            --oui-file) OUI_FILE="$2"; shift 2;;
            --oui-filter-mode) OUI_FILTER_MODE="$2"; shift 2;;
            --stay-time) STAY_TIME="$2"; shift 2;;
            --wardriving-loop) WARDRIVING_LOOP="$2"; shift 2;;
            --hcxd-opts) HCXD_OPTS="$HCXD_OPTS $2"; shift 2;;
            --interactive) INTERACTIVE_MODE=1; shift;;
            --enable-gps) ENABLE_GPS=1; shift;;
            --live-db-log) LIVE_DB_LOG=1; BACKEND="hcxlabtool"; shift;;
            --rds) RDS_MODE="$2"; shift 2;;
            --backend)
                BACKEND="$2"
                if [ "$BACKEND" != "hcxdumptool" ] && [ "$BACKEND" != "hcxlabtool" ]; then
                    echo -e "${RED}Error: Invalid backend '$BACKEND'. Use 'hcxdumptool' or 'hcxlabtool'.${NC}" >&2
                    exit 1
                fi
                shift 2;;
            --hunt-handshakes) HUNT_HANDSHAKES=1; shift;;
            --passive) PASSIVE_MODE=1; shift;;
            --survey) SURVEY_MODE=1; shift;;
            --client-only-hunt) CLIENT_ONLY_HUNT=1; BACKEND="hcxlabtool"; shift;;
            --pmkid-priority-hunt) PMKID_PRIORITY_HUNT=1; BACKEND="hcxlabtool"; shift;;
            --time-warp-attack) TIME_WARP_ATTACK=1; BACKEND="hcxlabtool"; shift;;
            *)
                echo -e "${RED}Unknown option: '$1'${NC}" >&2
                usage
                exit 1
                ;;
        esac
    done
    
    if [ -n "$FILTER_FILE" ] && [ -n "$OUI_FILE" ]; then
        echo -e "${RED}Error: Cannot use --filter-file and --oui-file at the same time.${NC}" >&2
        exit 1
    fi
    if [ -n "$BPF_FILE" ] && ( [ -n "$FILTER_FILE" ] || [ -n "$OUI_FILE" ] ); then
         echo -e "${RED}Error: Cannot use a pre-compiled BPF with dynamic MAC/OUI filters.${NC}" >&2
         exit 1
    fi
    
    log_message "Launcher started."
    if [ "$QUIET" -eq 0 ]; then show_banner; fi
    
    dependency_check
    
    generate_bpf_from_mac_list
    generate_bpf_from_oui_list

    if [ "$INTERACTIVE_MODE" -eq 1 ]; then interactive_mode; fi
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
