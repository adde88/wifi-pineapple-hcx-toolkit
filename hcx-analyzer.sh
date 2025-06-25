#!/bin/sh
#
# HCX Advanced Analyzer - Masterpiece Edition
# A comprehensive security analysis and reporting tool for HCX captures.
# Part of the WiFi Pineapple HCX Toolkit
# Version: 5.0.0

#==============================================================================
# INITIALIZATION & CONFIGURATION
#==============================================================================

# --- Script Version ---
ANALYZER_VERSION="5.0.0"

# --- System & Path Configuration ---
if [ -f "/etc/hcxtools/hcxscript.conf" ]; then
    . "/etc/hcxtools/hcxscript.conf"
fi
CAPTURE_DIR=${OUTPUT_DIR:-"/root/hcxdumps"}
ANALYSIS_DIR="/root/hcx-analysis"
mkdir -p "$ANALYSIS_DIR"

# --- Set Defaults for Remote Cracking (if not set in conf) ---
REMOTE_CRACK_ENABLED=${REMOTE_CRACK_ENABLED:-0}
REMOTE_USER=${REMOTE_USER:-"user"}
REMOTE_HOST=${REMOTE_HOST:-"192.168.1.100"}
REMOTE_HASHCAT_PATH=${REMOTE_HASHCAT_PATH:-"/usr/bin/hashcat"}
REMOTE_WORDLIST_PATH=${REMOTE_WORDLIST_PATH:-"/path/to/your/wordlist.txt"}
REMOTE_CAPTURE_PATH=${REMOTE_CAPTURE_PATH:-"/home/user/hcx_captures"}

# --- Colors ---
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'

# --- Script Defaults ---
MODE="summary"
SUMMARY_MODE="deep"
VERBOSE=0

#==============================================================================
# HELPER FUNCTIONS
#==============================================================================

show_usage() {
    echo "HCX Advanced Analyzer v$ANALYZER_VERSION"
    echo "Usage: $0 [options] [file/dir1] [file/dir2] ..."
    echo ""
    echo "Analyzes .pcapng files from given paths, or from the default directory: $CAPTURE_DIR"
    echo "If run without mode options, an interactive menu will be shown."
    echo ""
    echo "Options:"
    echo "  --mode <mode>         Analysis mode. Default: summary."
    echo "                        - summary: Overview of hashes, networks, and devices."
    echo "                        - intel: Deep intelligence gathering (vendors, hash grouping)."
    echo "                        - vuln: Hunt for weak passwords and known vulnerabilities."
    echo "                        - export: Convert data for use in other tools."
    echo "                        - geotrack: Extract and save GPS data from captures."
    echo "                        - remote-crack: Offload hash file for cracking. See notes below."
    echo "  --summary-mode <type> Select summary type (quick|deep). Default: deep."
    echo "  -v, --verbose         Enable verbose output for debugging."
    echo "  -h, --help            Show this help message."
    echo ""
    echo -e "${YELLOW}Remote Crack Note:${NC} The remote-crack feature requires configuration."
    echo -e "Edit ${CYAN}/etc/hcxtools/hcxscript.conf${NC} to set your remote host, user, and paths."
    echo ""
}

# Spinner function to provide visual feedback for long tasks
run_with_spinner() {
    local cmd="$1"
    shift
    local args="$@"
    
    # Spinner function runs in the background
    spinner() {
        local spinstr='|/-\\'
        while true; do
            local temp=${spinstr#?}
            printf " [%c] " "$spinstr"
            spinstr=$temp${spinstr%"$temp"}
            sleep 0.1
            printf "\b\b\b\b\b"
        done
    }

    spinner &
    local spinner_pid=$!
    # Ensure spinner is killed on script exit
    trap "kill $spinner_pid 2>/dev/null; printf '\b\b\b\b\b     \b\b\b\b\b'; exit" INT TERM EXIT

    # Run the actual command, hiding its output
    $cmd $args >/dev/null 2>&1
    
    # Kill the spinner and clean up the line
    kill $spinner_pid 2>/dev/null
    printf "\b\b\b\b\b     \b\b\b\b\b"
    # Disable the trap
    trap - INT TERM EXIT
}

#==============================================================================
# ANALYSIS CORE
#==============================================================================

run_summary_analysis() {
    shift
    local files_to_process="$@"
    local ALL_HASHES_FILE="$ANALYSIS_DIR/all_hashes.hc22000"
    local TEMP_ESSID_FILE="/tmp/analyzer_essids.tmp"
    local TEMP_DEVICE_FILE="/tmp/analyzer_devices.tmp"

    >"$ALL_HASHES_FILE"; >"$TEMP_ESSID_FILE"; >"$TEMP_DEVICE_FILE"

    echo -e "${CYAN}--- Running Summary Analysis (Mode: $SUMMARY_MODE) ---${NC}"
    printf "Processing all files..."
    
    if [ "$VERBOSE" -eq 1 ]; then
        printf "\n" # Add a newline for verbose output
        hcxpcapngtool $files_to_process -o "$ALL_HASHES_FILE" -E "$TEMP_ESSID_FILE" -D "$TEMP_DEVICE_FILE"
    else
        run_with_spinner "hcxpcapngtool" $files_to_process -o "$ALL_HASHES_FILE" -E "$TEMP_ESSID_FILE" -D "$TEMP_DEVICE_FILE"
        printf " Done.\n"
    fi

    local TOTAL_HASHES=0; local PMKID_COUNT=0; local EAPOL_COUNT=0;
    local ESSID_COUNT=0; local DEVICE_COUNT=0;
    
    if [ -s "$ALL_HASHES_FILE" ]; then
        if [ "$SUMMARY_MODE" = "deep" ]; then
            TOTAL_HASHES=$(wc -l < "$ALL_HASHES_FILE")
            PMKID_COUNT=$(hcxhashtool -i "$ALL_HASHES_FILE" --type=1 2>/dev/null | wc -l)
            EAPOL_COUNT=$(hcxhashtool -i "$ALL_HASHES_FILE" --type=2 2>/dev/null | wc -l)
        else
            TOTAL_HASHES=$(wc -l < "$ALL_HASHES_FILE")
            PMKID_COUNT="N/A (Quick Mode)"
            EAPOL_COUNT="N/A (Quick Mode)"
        fi
    fi
    if [ -s "$TEMP_ESSID_FILE" ]; then ESSID_COUNT=$(sort -u "$TEMP_ESSID_FILE" | wc -l); fi
    if [ -s "$TEMP_DEVICE_FILE" ]; then DEVICE_COUNT=$(sort -u "$TEMP_DEVICE_FILE" | wc -l); fi

    echo -e "\n${BLUE}--- Overall Summary ---${NC}"
    echo -e "[*] Total Crackable Hashes:         ${GREEN}$TOTAL_HASHES${NC}"
    if [ "$SUMMARY_MODE" = "deep" ]; then
        echo -e "    - PMKIDs (AP-based):            ${YELLOW}$PMKID_COUNT${NC}"
        echo -e "    - Handshakes (Client-based):    ${YELLOW}$EAPOL_COUNT${NC}"
    fi
    echo -e "[*] Total Unique ESSIDs (Networks): ${GREEN}$ESSID_COUNT${NC}"
    echo -e "[*] Total Unique Devices (MACs):    ${GREEN}$DEVICE_COUNT${NC}"
    
    if [ ! -s "$ALL_HASHES_FILE" ]; then
        rm -f "$ALL_HASHES_FILE"
    else
        echo -e "\n${GREEN}All crackable hashes saved to: $ALL_HASHES_FILE${NC}"
    fi
    rm -f "$TEMP_ESSID_FILE" "$TEMP_DEVICE_FILE" 2>/dev/null
}

run_intel_analysis() {
    shift
    local files_to_process="$@"
    local ALL_HASHES_FILE="$ANALYSIS_DIR/all_hashes.hc22000"

    echo -e "${CYAN}--- Running Intelligence Gathering ---${NC}"
    printf "Extracting hashes..."
    if [ "$VERBOSE" -eq 1 ]; then printf "\n"; hcxpcapngtool $files_to_process -o "$ALL_HASHES_FILE"; else run_with_spinner "hcxpcapngtool" $files_to_process -o "$ALL_HASHES_FILE"; printf " Done.\n"; fi
    
    if [ ! -s "$ALL_HASHES_FILE" ]; then
        echo -e "${YELLOW}No hashes found to analyze.${NC}"
        return
    fi
    
    echo -e "\n${BLUE}--- Hash Content Information ---${NC}"
    hcxhashtool -i "$ALL_HASHES_FILE" --info=stdout
    
    echo -e "\n${BLUE}--- Discovered Device Vendors ---${NC}"
    hcxhashtool -i "$ALL_HASHES_FILE" --info-vendor=stdout

    echo -e "\n${BLUE}--- Hash Grouping for Efficient Cracking ---${NC}"
    echo "Grouping hashes by ESSID optimizes cracking performance by reusing PBKDF2 calculations."
    echo "Grouped hash files will be saved to: $ANALYSIS_DIR/grouped-hashes/"
    mkdir -p "$ANALYSIS_DIR/grouped-hashes"
    hcxhashtool -i "$ALL_HASHES_FILE" --essid-group --oui-group -d >/dev/null 2>&1
    mv ESSID-*.hc22000 OUI-*.hc22000 "$ANALYSIS_DIR/grouped-hashes/" 2>/dev/null
    echo -e "${GREEN}Grouping complete.${NC}"
}

run_vulnerability_analysis() {
    shift
    local files_to_process="$@"
    local ALL_HASHES_FILE="$ANALYSIS_DIR/all_hashes.hc22000"
    local ALL_ESSIDS_FILE="$ANALYSIS_DIR/all_essids.txt"

    echo -e "${CYAN}--- Running Vulnerability Analysis ---${NC}"
    printf "Extracting hashes and ESSIDs..."
    if [ "$VERBOSE" -eq 1 ]; then printf "\n"; hcxpcapngtool $files_to_process -o "$ALL_HASHES_FILE" -E "$ALL_ESSIDS_FILE"; else run_with_spinner "hcxpcapngtool" $files_to_process -o "$ALL_HASHES_FILE" -E "$ALL_ESSIDS_FILE"; printf " Done.\n"; fi

    if [ ! -s "$ALL_HASHES_FILE" ]; then
        echo -e "${YELLOW}No crackable hashes found. Cannot perform vulnerability analysis.${NC}"
        return
    fi

    echo -e "\n${BLUE}--- Comprehensive Default Password Check ---${NC}"
    echo "Testing against thousands of known default router passwords..."
    hcxpsktool -c "$ALL_HASHES_FILE" --netgear --spectrum --weakpass --digit10 --phome --tenda --ee --alticeoptimum --asus | tee "$ANALYSIS_DIR/cracked_by_defaults.txt"

    echo -e "\n${BLUE}--- ESSID-based Wordlist Generation ---${NC}"
    echo "Generating potential passwords based on captured network names..."
    local CANDIDATE_WORDLIST="$ANALYSIS_DIR/essid_based_wordlist.txt"
    if [ "$VERBOSE" -eq 1 ]; then hcxeiutool -i "$ALL_ESSIDS_FILE" -s "$CANDIDATE_WORDLIST"; else hcxeiutool -i "$ALL_ESSIDS_FILE" -s "$CANDIDATE_WORDLIST" >/dev/null 2>&1; fi
    if [ -s "$CANDIDATE_WORDLIST" ]; then
        echo "Candidate wordlist saved to: $CANDIDATE_WORDLIST"
        echo -e "Use this file with hashcat on a powerful machine, or with the 'remote-crack' mode."
    else
        echo "No candidate passwords could be generated from ESSIDs."
    fi

    echo -e "\n${BLUE}--- AP-Less (Client-Only) Attack Candidates ---${NC}"
    hcxhashtool -i "$ALL_HASHES_FILE" --apless -o "$ANALYSIS_DIR/apless_targets.hc22000"
    if [ -s "$ANALYSIS_DIR/apless_targets.hc22000" ]; then
        echo "Targets vulnerable to AP-less attacks saved to: $ANALYSIS_DIR/apless_targets.hc22000"
    else
        echo "No AP-less attack targets found."
        rm -f "$ANALYSIS_DIR/apless_targets.hc22000" 2>/dev/null
    fi

    echo -e "\n${BLUE}--- Legacy Protocol Scan ---${NC}"
    if [ "$VERBOSE" -eq 1 ]; then hcxpcapngtool $files_to_process --eapmd5="$ANALYSIS_DIR/eap-md5.hash" --eapleap="$ANALYSIS_DIR/eap-leap.hash"; else hcxpcapngtool $files_to_process --eapmd5="$ANALYSIS_DIR/eap-md5.hash" --eapleap="$ANALYSIS_DIR/eap-leap.hash" >/dev/null 2>&1; fi
    if [ -s "$ANALYSIS_DIR/eap-md5.hash" ]; then echo -e "${YELLOW}Vulnerable EAP-MD5 hashes found! Saved to eap-md5.hash${NC}"; fi
    if [ -s "$ANALYSIS_DIR/eap-leap.hash" ]; then echo -e "${YELLOW}Vulnerable EAP-LEAP hashes found! Saved to eap-leap.hash${NC}"; fi

    echo -e "\n${GREEN}--- Vulnerability Report Complete ---${NC}"
    echo "Detailed reports and hash files have been saved in: $ANALYSIS_DIR/"
}

run_export_analysis() {
    shift
    local files_to_process="$@"
    local ALL_HASHES_FILE="$ANALYSIS_DIR/all_hashes.hc22000"

    echo -e "${CYAN}--- Running Export Analysis ---${NC}"
    printf "Extracting hashes..."
    if [ "$VERBOSE" -eq 1 ]; then printf "\n"; hcxpcapngtool $files_to_process -o "$ALL_HASHES_FILE"; else run_with_spinner "hcxpcapngtool" $files_to_process -o "$ALL_HASHES_FILE"; printf " Done.\n"; fi

    if [ ! -s "$ALL_HASHES_FILE" ]; then
        echo -e "${YELLOW}No hashes found to export.${NC}"
        return
    fi
    
    echo -e "\n${BLUE}--- Exporting to Legacy .cap Format ---${NC}"
    if [ "$VERBOSE" -eq 1 ]; then hcxhash2cap -c "$ANALYSIS_DIR/legacy_captures.cap" --pmkid-eapol="$ALL_HASHES_FILE"; else hcxhash2cap -c "$ANALYSIS_DIR/legacy_captures.cap" --pmkid-eapol="$ALL_HASHES_FILE" >/dev/null 2>&1; fi
    echo "Legacy .cap file saved to: $ANALYSIS_DIR/legacy_captures.cap"

    echo -e "\n${BLUE}--- Exporting Network Information to CSV ---${NC}"
    if [ "$VERBOSE" -eq 1 ]; then hcxpcapngtool $files_to_process --csv="$ANALYSIS_DIR/networks_summary.csv"; else hcxpcapngtool $files_to_process --csv="$ANALYSIS_DIR/networks_summary.csv" >/dev/null 2>&1; fi
    echo "Network summary saved to: $ANALYSIS_DIR/networks_summary.csv"

    echo -e "\n${GREEN}--- Export Complete ---${NC}"
    echo "All exported files are in: $ANALYSIS_DIR/"
}

run_geotrack_analysis() {
    shift
    local files_to_process="$@"
    local NMEA_FILE="$ANALYSIS_DIR/wardriving_track.nmea"
    
    echo -e "${CYAN}--- Running Geotracking Analysis ---${NC}"
    
    if ! command -v hcxnmealog >/dev/null 2>&1; then
        echo -e "${RED}Error: hcxnmealog is not installed. This feature requires the latest hcxtools package.${NC}"
        return
    fi

    printf "Extracting GPS and network data..."
    if [ "$VERBOSE" -eq 1 ]; then printf "\n"; hcxnmealog -i "$files_to_process" -n "$NMEA_FILE"; else run_with_spinner "hcxnmealog" -i "$files_to_process" -n "$NMEA_FILE"; printf " Done.\n"; fi
    
    echo -e "\n${GREEN}--- Geotracking Export Complete ---${NC}"
    if [ -s "$NMEA_FILE" ]; then
        echo "NMEA track file saved to: $NMEA_FILE"
        echo "You can convert this to KML for Google Earth with:"
        echo -e "${CYAN}gpsbabel -w -t -i nmea -f $NMEA_FILE -o kml -F track.kml${NC}"
    else
        echo -e "${YELLOW}No GPS data was found in the capture files.${NC}"
    fi
}

run_remote_crack_analysis() {
    shift
    local files_to_process="$@"
    local ALL_HASHES_FILE="$ANALYSIS_DIR/all_hashes.hc22000"

    echo -e "${CYAN}--- Running Remote Cracking Offload ---${NC}"
    
    if [ "$REMOTE_CRACK_ENABLED" -eq 0 ]; then
        echo -e "${YELLOW}Remote cracking is disabled. Please edit /etc/hcxtools/hcxscript.conf to enable it.${NC}"
        return
    fi

    printf "Extracting hashes..."
    if [ "$VERBOSE" -eq 1 ]; then printf "\n"; hcxpcapngtool $files_to_process -o "$ALL_HASHES_FILE"; else run_with_spinner "hcxpcapngtool" $files_to_process -o "$ALL_HASHES_FILE"; printf " Done.\n"; fi
    if [ ! -s "$ALL_HASHES_FILE" ]; then
        echo -e "${YELLOW}No hashes found to crack.${NC}"
        return
    fi

    echo -e "You are about to send ${GREEN}$(basename "$ALL_HASHES_FILE")${NC} to ${GREEN}${REMOTE_USER}@${REMOTE_HOST}${NC}"
    printf "Are you sure you want to continue? [y/N] "
    read -r response
    if ! (echo "$response" | grep -qE '^[yY]([eE][sS])?$'); then
        echo "Remote cracking cancelled."
        return
    fi

    echo "Uploading hash file..."
    scp "$ALL_HASHES_FILE" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_CAPTURE_PATH}/"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: SCP upload failed. Check your connection and configuration in /etc/hcxtools/hcxscript.conf.${NC}"
        return
    fi

    local remote_hash_file="${REMOTE_CAPTURE_PATH}/$(basename "$ALL_HASHES_FILE")"
    local remote_potfile="${REMOTE_CAPTURE_PATH}/cracked.pot"
    local HASHCAT_CMD="'$REMOTE_HASHCAT_PATH' -m 22000 '$remote_hash_file' '$REMOTE_WORDLIST_PATH' --potfile-path '$remote_potfile'"

    echo -e "\n${BLUE}--- Starting Remote Hashcat Session ---${NC}"
    echo "Executing the following command on ${REMOTE_HOST}:"
    echo -e "${YELLOW}${HASHCAT_CMD}${NC}"
    
    ssh "${REMOTE_USER}@${REMOTE_HOST}" "nohup sh -c \"${HASHCAT_CMD}\" > /dev/null 2>&1 &"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: SSH command failed. Check your connection and configuration in /etc/hcxtools/hcxscript.conf.${NC}"
        return
    fi

    echo -e "\n${GREEN}--- Remote Cracking Session Started! ---${NC}"
    echo "Hashcat is now running in the background on ${REMOTE_HOST}."
    echo "You can check its progress by logging into the remote server."
    echo "To retrieve cracked passwords later, run this command from your local machine:"
    echo -e "${CYAN}scp ${REMOTE_USER}@${REMOTE_HOST}:${remote_potfile} . && ${REMOTE_HASHCAT_PATH} --show -m 22000 ${ALL_HASHES_FILE} --potfile-path cracked.pot${NC}"
}

run_interactive_mode() {
    echo -e "${CYAN}--- HCX Analyzer Interactive Mode ---${NC}"
    echo "Please select an analysis mode:"
    echo "  1) Summary (Fast overview of captures)"
    echo "  2) Intelligence (Deep analysis of devices and vendors)"
    echo "  3) Vulnerability (Check for weak passwords and flaws)"
    echo "  4) Export (Convert data for other tools)"
    echo "  5) Geotrack (Extract GPS data to a map file)"
    echo "  6) Remote Crack (Offload cracking to a powerful machine)"
    printf "Choice [1-6]: "
    read -r mode_choice

    case "$mode_choice" in
        1) 
            MODE="summary"
            echo -e "\nThe Summary mode can be run in two ways:"
            echo "  1) Quick (Fast, but gives a less detailed hash count)"
            echo "  2) Deep  (Slower, but provides an accurate PMKID vs Handshake count)"
            echo -e "${YELLOW}Warning: Deep mode can take a while on the Pineapple with large captures.${NC}"
            printf "Summary type [1-2]: "
            read -r summary_choice
            case "$summary_choice" in
                1) SUMMARY_MODE="quick";;
                2) SUMMARY_MODE="deep";;
                *) echo "${RED}Invalid choice. Defaulting to deep analysis.${NC}"; SUMMARY_MODE="deep";;
            esac
            ;;
        2) MODE="intel";;
        3) MODE="vuln";;
        4) MODE="export";;
        5) MODE="geotrack";;
        6) MODE="remote-crack";;
        *) echo "${RED}Invalid choice. Exiting.${NC}"; exit 1;;
    esac
}

#==============================================================================
# SCRIPT EXECUTION
#==============================================================================

main() {
    local TARGET_ARGS=""
    local has_mode_arg=0
    
    for arg in "$@"; do
        if [ "$arg" = "--mode" ]; then
            has_mode_arg=1
        fi
    done

    # If no mode is specified via arguments, and it's not a help request, enter interactive mode
    if [ "$has_mode_arg" -eq 0 ] && [ "$1" != "-h" ] && [ "$1" != "--help" ]; then
        is_only_files=1
        for arg in "$@"; do
            # If an argument is not a file or directory, it's not a simple file list run
            if [ -n "$arg" ] && [ ! -f "$arg" ] && [ ! -d "$arg" ]; then
                is_only_files=0
                break
            fi
        done
        if [ "$is_only_files" -eq 1 ] && [ $# -gt 0 ]; then
            has_mode_arg=1 # Treat file list as a non-interactive run
        fi
    fi
    
    if [ "$has_mode_arg" -eq 0 ] && [ "$1" != "-h" ] && [ "$1" != "--help" ]; then
        run_interactive_mode
    else
        # Normal argument parsing
        while [ $# -gt 0 ]; do
            case "$1" in
                --mode) MODE="$2"; shift 2 ;;
                --summary-mode) SUMMARY_MODE="$2"; shift 2;;
                -v|--verbose) VERBOSE=1; shift ;;
                -h|--help) show_usage; exit 0 ;;
                *) if [ -z "$TARGET_ARGS" ]; then TARGET_ARGS="$1"; else TARGET_ARGS="$TARGET_ARGS $1"; fi; shift ;;
            esac
        done
    fi

    if ! command -v hcxpcapngtool >/dev/null 2>&1; then
        echo -e "${RED}Error: hcxtools-custom package not found or not in PATH.${NC}"
        exit 1
    fi
    
    local files_to_analyze=""
    if [ -z "$TARGET_ARGS" ]; then
        if [ ! -d "$CAPTURE_DIR" ]; then
            echo -e "${RED}Error: Default capture directory not found: $CAPTURE_DIR${NC}"
            exit 1
        fi
        files_to_analyze=$(find "$CAPTURE_DIR" -name "*.pcapng")
    else
        for path in $TARGET_ARGS; do
            if [ -d "$path" ]; then
                files_to_analyze="$files_to_analyze $(find "$path" -name '*.pcapng')"
            elif [ -f "$path" ]; then
                files_to_analyze="$files_to_analyze $path"
            fi
        done
    fi
    
    if [ -z "$files_to_analyze" ]; then
        echo -e "${YELLOW}No .pcapng files found in the specified path(s).${NC}"
        exit 0
    fi

    case "$MODE" in
        summary) run_summary_analysis "summary" $files_to_analyze ;;
        intel) run_intel_analysis "intel" $files_to_analyze ;;
        vuln) run_vulnerability_analysis "vuln" $files_to_analyze ;;
        export) run_export_analysis "export" $files_to_analyze ;;
        geotrack) run_geotrack_analysis "geotrack" $files_to_analyze ;;
        remote-crack) run_remote_crack_analysis "remote-crack" $files_to_analyze ;;
        *) echo -e "${RED}Invalid mode selected.${NC}"; show_usage; exit 1 ;;
    esac

    echo -e "\n${GREEN}Analyzer finished.${NC}"
}

main "$@"