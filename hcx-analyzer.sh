#!/bin/sh
#
# HCX Advanced Analyzer - v7.0.0 "Hydra"
#
# (C) 2025 Andreas Nilsen. All rights reserved.

#==============================================================================
# INITIALIZATION & CONFIGURATION
#==============================================================================

# --- Script Version ---
ANALYZER_VERSION="7.1.0 \"Hydra-Intel\""

# --- System & Path Configuration ---
if [ -f "/etc/hcxtools/hcxscript.conf" ]; then
    # shellcheck disable=SC1091
    . "/etc/hcxtools/hcxscript.conf"
fi

# --- Local Paths ---
CAPTURE_DIR=${OUTPUT_DIR:-"/root/hcxdumps"}
ANALYSIS_DIR="/root/hcx-analysis"
DB_DIR="/root/hcxdumps"
DB_FILE="$DB_DIR/database.db"
LIVE_LOG_FILE="/tmp/hcx_live_survey.log"
mkdir -p "$ANALYSIS_DIR"
mkdir -p "$DB_DIR"

# --- UNIFIED REMOTE SERVER CONFIGURATION ---
# --- Cloud Sync Defaults ---
CLOUD_SYNC_ENABLED=${CLOUD_SYNC_ENABLED:-0}
RCLONE_REMOTE_NAME=${RCLONE_REMOTE_NAME:-""}
RCLONE_REMOTE_PATH=${RCLONE_REMOTE_PATH:-"HCX-Captures"}
# --- Push Notification Defaults ---
NOTIFICATION_ENABLED=${NOTIFICATION_ENABLED:-0}
NOTIFICATION_SERVICE=${NOTIFICATION_SERVICE:-"ntfy"}
NOTIFICATION_URL=${NOTIFICATION_URL:-""}
REMOTE_SERVER_ENABLED=${REMOTE_ANALYSIS_ENABLED:-1}
REMOTE_SERVER_HOST=${REMOTE_HOST:-"192.168.1.20"}
REMOTE_SERVER_USER=${REMOTE_USER:-"root"}

# Correctly determine home directory for root vs. other users
if [ "$REMOTE_SERVER_USER" = "root" ]; then
    REMOTE_SERVER_BASE_PATH="/root"
else
    REMOTE_SERVER_BASE_PATH="/home/${REMOTE_SERVER_USER}"
fi
REMOTE_SERVER_TMP_PATH="${REMOTE_SERVER_BASE_PATH}/hcx_analysis_temp"
REMOTE_CAPTURE_PATH="${REMOTE_SERVER_BASE_PATH}/hcx_captures"


# --- Remote Cracking Specifics ---
REMOTE_HASHCAT_PATH=${REMOTE_HASHCAT_PATH:-"/usr/bin/hashcat"}
REMOTE_WORDLIST_PATH=${REMOTE_WORDLIST_PATH:-"/usr/share/wordlists/rockyou.txt"}

# --- Remote DB Specifics ---
DB_HOST=${DB_HOST:-"127.0.0.1"}
DB_USER=${DB_USER:-"root"}
DB_PASS=${DB_PASS:-""}
DB_NAME=${DB_NAME:-"hcx_toolkit"}

# --- Colors ---
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'

# --- Script State Variables ---
SESSION_TAG=""
MODE=""
UTILITY_ACTION=""
MONITOR_CRACK=0
REMOTE_ACTION=0
VERBOSE=0
SUMMARY_MODE="deep"
MAC_LIST=""
MAC_SKIPLIST=""
ESSID_FILTER=""
VENDOR_FILTER=""
ESSID_MIN_LEN=""
ESSID_MAX_LEN=""
HASH_TYPE=""
ESSID_REGEX=""
AUTHORIZED_ONLY=0
CHALLENGE_ONLY=0

#==============================================================================
# HELPER & CORE FUNCTIONS
#==============================================================================

show_usage() {
    printf "%b\n" "${GREEN}HCX Advanced Analyzer v$ANALYZER_VERSION${NC}"
    printf "%b\n" "by: ${YELLOW}Andreas Nilsen <adde88@gmail.com>${NC}"
    printf "\n"
    printf "Usage: %s [options] [file/dir1] ...\n" "$0"
    printf "\n"
    printf "%b\n" "${CYAN}--- LOCAL EXECUTION MODES ---${NC}"
    printf "  ${GREEN}--mode <name>${NC}            Run a primary analysis task locally. Options:\n"
    printf "                           ${YELLOW}%-15s${NC} %s\n" "summary" "Quick overview of captures and hashes."
    printf "                           ${YELLOW}%-15s${NC} %s\n" "intel" "Deep-dive into device vendors and relationships."
    printf "                           ${YELLOW}%-15s${NC} %s\n" "vuln" "Hunt for known default passwords and weak points."
    printf "                           ${YELLOW}%-15s${NC} %s\n" "pii" "Scan for Personally Identifiable Information (usernames/identities)."
    printf "                           ${YELLOW}%-15s${NC} %s\n" "recommend" "Analyze data and suggest strategic next steps."
    printf "                           ${YELLOW}%-15s${NC} %s\n" "trends" "Analyze network changes and activity over time from the database."
    printf "                           ${YELLOW}%-15s${NC} %s\n" "db" "Log all findings to a local SQLite database file."
    printf "                           ${YELLOW}%-15s${NC} %s\n" "interactive" "Launch the guided menu for local operations."
    printf "\n"
    printf "%b\n" "${CYAN}--- REMOTE EXECUTION MODES ---${NC}"
    printf "  ${GREEN}--remote-mode <name>${NC}    Offload a primary analysis task to the remote server. Options:\n"
    printf "                           ${YELLOW}%-15s${NC} %s\n" "summary" "Run a quick overview on the remote server."
    printf "                           ${YELLOW}%-15s${NC} %s\n" "intel" "Run a deep-dive analysis on the remote server."
    printf "                           ${YELLOW}%-15s${NC} %s\n" "vuln" "Hunt for vulnerabilities on the remote server."
    printf "                           ${YELLOW}%-15s${NC} %s\n" "pii" "Run PII scan on the remote server."
    printf "                           ${YELLOW}%-15s${NC} %s\n" "db" "Analyze remotely, then update the LOCAL SQLite DB."
    printf "                           ${YELLOW}%-15s${NC} %s\n" "mysql" "Analyze remotely and update a remote MySQL DB."
    printf "                           ${YELLOW}%-15s${NC} %s\n" "interactive" "Run the interactive menu on the remote server."
    printf "\n"
    printf "%b\n" "${CYAN}--- UTILITY MODES (LOCAL) ---${NC}"
    printf "  ${GREEN}--utility <name>${NC}        Run a local utility task. Options:\n"
    printf "                           ${YELLOW}%-15s${NC} %s\n" "setup-remote" "Interactive wizard to configure a remote analysis server."
    printf "                           ${YELLOW}%-15s${NC} %s\n" "find-reuse-targets" "Report on potential Wi-Fi password reuse."
    printf "                           ${YELLOW}%-15s${NC} %s\n" "filter_hashes" "Create a new hash file based on specific criteria."
    printf "                           ${YELLOW}%-15s${NC} %s\n" "generate_wordlist" "Build a custom wordlist from captured network names."
    printf "                           ${YELLOW}%-15s${NC} %s\n" "generate-dashboard" "Create a professional HTML report of all findings."
    printf "                           ${YELLOW}%-15s${NC} %s\n" "merge_hashes" "Combine multiple .hc22000 files into one."
    printf "                           ${YELLOW}%-15s${NC} %s\n" "export" "Convert data to other formats like .csv or .cap."
    printf "                           ${YELLOW}%-15s${NC} %s\n" "geotrack" "Create a KML map file from GPS data."
    printf "                           ${YELLOW}%-15s${NC} %s\n" "remote_crack" "Offload cracking to a remote Hashcat server."
    printf "                           ${YELLOW}%-15s${NC} %s\n" "health_check" "Verify hcxtools versions and dependencies."
    printf "\n"
    printf "%b\n" "${CYAN}--- UTILITY MODES (REMOTE) ---${NC}"
    printf "  ${GREEN}--remote-utility <name>${NC} Offload a utility task. Options:\n"
    printf "                           ${YELLOW}%-15s${NC} %s\n" "filter_hashes" "Filter hashes on the remote server."
    printf "                           ${YELLOW}%-15s${NC} %s\n" "generate_wordlist" "Generate wordlist on the remote server."
    printf "                           ${YELLOW}%-15s${NC} %s\n" "merge_hashes" "Merge hash files on the remote server."
    printf "                           ${YELLOW}%-15s${NC} %s\n" "export" "Export to CSV/CAP on the remote server."
    printf "                           ${YELLOW}%-15s${NC} %s\n" "geotrack" "Generate KML file on the remote server."
    printf "\n"
    printf "%b\n" "${CYAN}--- DATA MANAGEMENT & OFFLOADING ---${NC}"
    printf "  ${GREEN}--utility <name>${NC}        Manage and synchronize data. Options:\n"
    printf "                           ${YELLOW}%-15s${NC} %s\n" "cloud-sync" "Sync captures and results with a configured cloud provider."
    printf "\n"
    printf "%b\n" "${CYAN}--- ADVANCED FILTERING OPTIONS (for filter_hashes mode) ---${NC}"
    printf "  ${GREEN}--essid-min <len>${NC}       Filter hashes with ESSID length >= len.\n"
    printf "  ${GREEN}--essid-max <len>${NC}       Filter hashes with ESSID length <= len.\n"
    printf "  ${GREEN}--essid-regex <RGX>${NC}     Filter hashes with ESSID matching a regex.\n"
    printf "  ${GREEN}--type <1|2|3>${NC}          Filter by hash type (1=PMKID, 2=EAPOL, 3=Both).\n"
    printf "  ${GREEN}--authorized${NC}            Keep only fully authorized handshakes.\n"
    printf "  ${GREEN}--challenge${NC}             Keep only challenge/response handshakes.\n"
    printf "\n"
    printf "%b\n" "${CYAN}--- OTHER OPTIONS ---${NC}"
    printf "  ${GREEN}--remote-host <host>${NC}    Specify remote server IP or hostname.\n"
    printf "  ${GREEN}--tag <name>${NC}            Filter analysis to only include captures with this session tag.\n"
    printf "  ${GREEN}--summary-mode <type>${NC}   For summary mode: quick|deep (Default: deep).\n"
    printf "  ${GREEN}--mac-list <file>${NC}       Whitelist MACs for hash filtering.\n"
    printf "  ${GREEN}--mac-skiplist <file>${NC}   Blacklist MACs for hash filtering.\n"
    printf "  ${GREEN}--essid <ESSID>${NC}         Filter by a specific ESSID.\n"
    printf "  ${GREEN}--vendor <string>${NC}       Filter by a vendor name string.\n"
    printf "  ${GREEN}--monitor${NC}               For remote_crack: automatically monitor and show results.\n"
    printf "  ${GREEN}-v, --verbose${NC}           Enable verbose output for debugging.\n"
    printf "  ${GREEN}-h, --help${NC}              Show this help message.\n"
    printf "\n"
}

sanitize_arg() {
    echo "$1" | sed "s/'/'\\\\''/g"
}

run_with_spinner() {
    local message="$1"; local cmd="$2"; shift 2; local args="$@"
    printf "%s" "$message"
    spinner() {
        local spinstr='|/-\\'
        while true; do local temp=${spinstr#?}; printf " [%c] " "$spinstr"; spinstr=$temp${spinstr%"$temp"}; sleep 0.1; printf "\b\b\b\b\b"; done
    }
    spinner &
    local spinner_pid=$!
    trap "kill $spinner_pid 2>/dev/null; printf '\b\b\b\b\b     \b\b\b\b\b'; exit" INT TERM EXIT
    if [ "$VERBOSE" -eq 1 ]; then printf "\n"; eval "$cmd $args"; else eval "$cmd $args" >/dev/null 2>&1; fi
    local exit_code=$?
    kill $spinner_pid 2>/dev/null; printf "\b\b\b\b\b     \b\b\b\b\b"; trap - INT TERM EXIT
    if [ $exit_code -eq 0 ]; then printf "${GREEN}Done.${NC}\n"; else printf "${RED}Failed.${NC}\n"; fi
    return $exit_code
}

#==============================================================================
# DATABASE & PARSING FUNCTIONS
#==============================================================================

initialize_database() {
    local db_type="$1"
    local db_target="$2"

    printf "Initializing and migrating database schema...\n"

    # This single block creates tables if they dont exist, ensuring the full, final schema.
    local schema_sql="
        CREATE TABLE IF NOT EXISTS networks (
            bssid TEXT PRIMARY KEY, 
            essid_b64 TEXT, 
            vendor TEXT,
            encryption_type TEXT,
            channel INTEGER,
            last_seen_rssi INTEGER,
            first_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            last_seen TIMESTAMP
        ) WITHOUT ROWID;

        CREATE TABLE IF NOT EXISTS clients (
            mac TEXT PRIMARY KEY, 
            vendor TEXT, 
            associated_bssid TEXT,
            first_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            last_seen TIMESTAMP
        ) WITHOUT ROWID;

        CREATE TABLE IF NOT EXISTS hashes (
            hash_content TEXT PRIMARY KEY, 
            hash_type TEXT, 
            bssid TEXT, 
            client_mac TEXT, 
            essid_b64 TEXT, 
            is_apless INTEGER,
            psk TEXT,
            cracked_timestamp DATETIME
        ) WITHOUT ROWID;

        CREATE TABLE IF NOT EXISTS credentials (
            id INTEGER PRIMARY KEY,
            source_mac TEXT NOT NULL,
            credential_type TEXT NOT NULL,
            credential_value TEXT NOT NULL,
            first_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    "
    # These ALTER statements handle migration from older schemas. Errors are suppressed.
    local migrate_sql="
        ALTER TABLE networks ADD COLUMN encryption_type TEXT;
        ALTER TABLE networks ADD COLUMN channel INTEGER;
        ALTER TABLE networks ADD COLUMN last_seen_rssi INTEGER;
        ALTER TABLE networks ADD COLUMN first_seen TIMESTAMP;
        ALTER TABLE networks ADD COLUMN last_seen TIMESTAMP;
        ALTER TABLE clients ADD COLUMN first_seen TIMESTAMP;
        ALTER TABLE clients ADD COLUMN last_seen TIMESTAMP;
        ALTER TABLE hashes ADD COLUMN psk TEXT;
        ALTER TABLE hashes ADD COLUMN cracked_timestamp DATETIME;
    "
    
    if [ "$db_type" = "sqlite3" ]; then
        echo "$schema_sql" | sqlite3 "$db_target"
        echo "$migrate_sql" | sqlite3 "$db_target" 2>/dev/null
    elif [ "$db_type" = "mysql" ]; then
        echo "Notice: Automatic schema setup is for SQLite. Please ensure your MySQL schema is current."
    fi
}

parse_and_update_from_live_log() {
    local db_type="$1"
    local db_target="$2"

    if [ ! -f "$LIVE_LOG_FILE" ]; then
        return 0
    fi

    printf "Parsing live survey data from RDS log...\n"
    
    local sql_batch_file="/tmp/live_update.sql"
    # This awk script is tuned to parse the machine-readable output of hcxlabtool --rds=1
    awk '/(WPA|OWE)/ {
        bssid = $1;
        rssi = $2;
        channel = $4;
        encryption = $7;
        gsub(/\047/, "", encryption);

        printf "INSERT OR IGNORE INTO networks (bssid, last_seen_rssi, channel, encryption_type, last_seen) VALUES (\047%s\047, %d, %d, \047%s\047, DATETIME(\047now\047));\n", bssid, rssi, channel, encryption;
        printf "UPDATE networks SET last_seen_rssi = %d, channel = %d, encryption_type = \047%s\047, last_seen = DATETIME(\047now\047) WHERE bssid = \047%s\047;\n", rssi, channel, encryption, bssid;
    }' "$LIVE_LOG_FILE" > "$sql_batch_file"

    if [ -s "$sql_batch_file" ]; then
        printf "Batch updating database with live network data...\n"
        if [ "$db_type" = "sqlite3" ]; then
            sqlite3 "$db_target" < "$sql_batch_file"
        elif [ "$db_type" = "mysql" ]; then
            mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$sql_batch_file"
        fi
    fi
    
    rm -f "$sql_batch_file" "$LIVE_LOG_FILE"
}

parse_and_update_db() {
    local db_type="$1"; shift; local all_hashes_file="$1"
    local sql_file="/tmp/db_update.sql"; >"$sql_file"
    printf "Parsing hash data and generating SQL...\n"
    
    # Use xxd to convert hex to base64 for ESSIDs
    while IFS= read -r line; do
        local essid_hex; essid_hex=$(echo "$line" | cut -d'*' -f5)
        local essid_b64; essid_b64=$(echo -n "$essid_hex" | xxd -r -p 2>/dev/null | base64)
        local bssid; bssid=$(echo "$line" | cut -d'*' -f3 | tr '[:lower:]' '[:upper:]')
        local client_mac; client_mac=$(echo "$line" | cut -d'*' -f4 | tr '[:lower:]' '[:upper:]')
        local hash_type; hash_type=$(echo "$line" | cut -d'*' -f1)
        local apless=0; [ "$hash_type" = "1" ] && apless=1
        local safe_line; safe_line=$(echo "$line" | sed "s/'/''/g")

        # Insert network if not exists
        echo "INSERT OR IGNORE INTO networks (bssid, essid_b64) VALUES ('$bssid', '$essid_b64');" >> "$sql_file"
        # Insert client if not exists
        [ "$client_mac" != "000000000000" ] && echo "INSERT OR IGNORE INTO clients (mac, associated_bssid) VALUES ('$client_mac', '$bssid');" >> "$sql_file"
        # Insert hash if not exists
        echo "INSERT OR IGNORE INTO hashes (hash_content, hash_type, bssid, client_mac, essid_b64, is_apless) VALUES ('$safe_line', '$hash_type', '$bssid', '$client_mac', '$essid_b64', $apless);" >> "$sql_file"
    done < "$all_hashes_file"
    
    # Update vendor info
    hcxhashtool -i "$all_hashes_file" --info-vendor=stdout 2>/dev/null | while read -r line; do
        local mac; mac=$(echo "$line" | awk '{print $1}' | tr '[:lower:]' '[:upper:]')
        local vendor; vendor=$(echo "$line" | cut -d' ' -f2- | sed "s/'/''/g")
        echo "UPDATE networks SET vendor = '$vendor' WHERE bssid = '$mac' AND vendor IS NULL;" >> "$sql_file"
        echo "UPDATE clients SET vendor = '$vendor' WHERE mac = '$mac' AND vendor IS NULL;" >> "$sql_file"
    done
    
    printf "Updating database with hash data...\n"
    if [ "$db_type" = "sqlite3" ]; then
        sqlite3 "$DB_FILE" < "$sql_file"
    elif [ "$db_type" = "mysql" ]; then
        mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$sql_file"
    fi
    rm -f "$sql_file"
}

#==============================================================================
# ANALYSIS & UTILITY FUNCTIONS
#==============================================================================

run_summary() {
    shift
    local files_to_process="$@"
    if [ -z "$files_to_process" ]; then files_to_process=$(find "$ANALYSIS_DIR" -name "*.pcapng"); fi
    if [ -z "$files_to_process" ]; then printf "%b\n" "${RED}No .pcapng files found to process.${NC}"; return 1; fi
    
    run_with_spinner "Processing files..." "hcxpcapngtool" $files_to_process -o "$ANALYSIS_DIR/all_hashes.hc22000" -E "/tmp/analyzer_essids.tmp" -D "/tmp/analyzer_devices.tmp"
    local ALL_HASHES_FILE="$ANALYSIS_DIR/all_hashes.hc22000"; local TEMP_ESSID_FILE="/tmp/analyzer_essids.tmp"; local TEMP_DEVICE_FILE="/tmp/analyzer_devices.tmp"
    local TOTAL_HASHES=0; local PMKID_COUNT=0; local EAPOL_COUNT=0; local ESSID_COUNT=0; local DEVICE_COUNT=0
    if [ -s "$ALL_HASHES_FILE" ]; then
        if [ "$SUMMARY_MODE" = "deep" ]; then
            TOTAL_HASHES=$(wc -l < "$ALL_HASHES_FILE"); PMKID_COUNT=$(hcxhashtool -i "$ALL_HASHES_FILE" --type=1 2>/dev/null | wc -l); EAPOL_COUNT=$(hcxhashtool -i "$ALL_HASHES_FILE" --type=2 2>/dev/null | wc -l)
        else
            TOTAL_HASHES=$(wc -l < "$ALL_HASHES_FILE"); PMKID_COUNT="N/A (Quick Mode)"; EAPOL_COUNT="N/A (Quick Mode)"
        fi
    fi
    if [ -s "$TEMP_ESSID_FILE" ]; then ESSID_COUNT=$(sort -u "$TEMP_ESSID_FILE" | wc -l); fi
    if [ -s "$TEMP_DEVICE_FILE" ]; then DEVICE_COUNT=$(sort -u "$TEMP_DEVICE_FILE" | wc -l); fi
    printf "\n%b\n" "${BLUE}--- Overall Summary ---${NC}"
    printf "%b\n" "[*] Total Crackable Hashes:         ${GREEN}$TOTAL_HASHES${NC}"
    if [ "$SUMMARY_MODE" = "deep" ]; then
        printf "%b\n" "    - PMKIDs (AP-based):            ${YELLOW}$PMKID_COUNT${NC}"; printf "%b\n" "    - Handshakes (Client-based):    ${YELLOW}$EAPOL_COUNT${NC}"
    fi
    printf "%b\n" "[*] Total Unique ESSIDs (Networks): ${GREEN}$ESSID_COUNT${NC}"; printf "%b\n" "[*] Total Unique Devices (MACs):    ${GREEN}$DEVICE_COUNT${NC}"
    if [ ! -s "$ALL_HASHES_FILE" ]; then rm -f "$ALL_HASHES_FILE"; fi
    rm -f "$TEMP_ESSID_FILE" "$TEMP_DEVICE_FILE" 2>/dev/null
}

run_intel() {
    shift
    local files_to_process="$@"
    if [ -z "$files_to_process" ]; then files_to_process=$(find "$ANALYSIS_DIR" -name "*.pcapng"); fi
    if [ -z "$files_to_process" ]; then printf "%b\n" "${RED}No .pcapng files found to process.${NC}"; return 1; fi
    
    run_with_spinner "Extracting hashes..." "hcxpcapngtool" $files_to_process -o "$ANALYSIS_DIR/all_hashes.hc22000"
    local ALL_HASHES_FILE="$ANALYSIS_DIR/all_hashes.hc22000"
    if [ ! -s "$ALL_HASHES_FILE" ]; then printf "%b\n" "${YELLOW}No hashes found.${NC}"; return; fi
    printf "\n%b\n" "${BLUE}--- Hash Content Information ---${NC}"; hcxhashtool -i "$ALL_HASHES_FILE" --info=stdout
    printf "\n%b\n" "${BLUE}--- Discovered Device Vendors ---${NC}"; hcxhashtool -i "$ALL_HASHES_FILE" --info-vendor=stdout
    printf "\n%b\n" "${BLUE}--- Hash Grouping for Efficient Cracking ---${NC}"
    mkdir -p "$ANALYSIS_DIR/grouped-hashes"; local current_dir=$(pwd); cd "$ANALYSIS_DIR/grouped-hashes" || exit
    run_with_spinner "Grouping hashes..." "hcxhashtool" -i "$ALL_HASHES_FILE" --essid-group --oui-group -d
    cd "$current_dir" || exit; echo "Grouped hash files saved to: $ANALYSIS_DIR/grouped-hashes/"
}

run_vuln() {
    shift
    local files_to_process="$@"
    if [ -z "$files_to_process" ]; then files_to_process=$(find "$CAPTURE_DIR" -name "*.pcapng" 2>/dev/null); fi
    if [ -z "$files_to_process" ]; then printf "%b\n" "${RED}No .pcapng files found to process.${NC}"; return 1; fi
    
    local ALL_HASHES_FILE="$ANALYSIS_DIR/all_hashes.hc22000"
    run_with_spinner "Extracting data..." "hcxpcapngtool" $files_to_process -o "$ALL_HASHES_FILE"
    if [ ! -s "$ALL_HASHES_FILE" ]; then printf "%b\n" "${YELLOW}No crackable hashes found.${NC}"; return; fi
    
    printf "\n%b\n" "${BLUE}--- Comprehensive Default Password Check ---${NC}"
    
    local psk_update_sql="/tmp/psk_updates.sql"
    > "$psk_update_sql"

    hcxpsktool -c "$ALL_HASHES_FILE" --netgear --spectrum --weakpass --digit10 --phome --tenda --ee --alticeoptimum --asus --eudate --usdate --wpskeys \
    | tee "$ANALYSIS_DIR/cracked_by_defaults.txt" \
    | awk -F: '{
        bssid = $1;
        psk = $3;
        gsub(/\047/, "\047\047", psk);
        printf "UPDATE hashes SET psk = \047%s\047, cracked_timestamp = DATETIME(\047now\047) WHERE bssid = \047%s\047;\n", psk, bssid;
    }' > "$psk_update_sql"

    if [ -s "$psk_update_sql" ] && [ -f "$DB_FILE" ]; then
        printf "Found cracked passwords! Updating database...\n"
        sqlite3 "$DB_FILE" < "$psk_update_sql"
        printf "%b\n" "${GREEN}Database updated with newly cracked PSKs.${NC}"
    fi
    rm -f "$psk_update_sql"
}

run_pii() {
    shift
    local files_to_process="$@"
    if [ -z "$files_to_process" ]; then files_to_process=$(find "$CAPTURE_DIR" -name "*.pcapng" 2>/dev/null); fi
    if [ -z "$files_to_process" ]; then printf "%b\n" "${RED}No .pcapng files found to process.${NC}"; return 1; fi
    
    printf "%b\n" "${CYAN}--- Scanning for Personally Identifiable Information ---${NC}"
    local ID_FILE="$ANALYSIS_DIR/identities.txt"; local USER_FILE="$ANALYSIS_DIR/usernames.txt"
    run_with_spinner "Extracting identities and usernames..." "hcxpcapngtool" $files_to_process -I "$ID_FILE" -U "$USER_FILE"
    
    printf "\n%b\n" "${BLUE}--- PII Scan Results ---${NC}"
    local credential_sql_file="/tmp/credential_updates.sql"
    > "$credential_sql_file"
    
    if [ -s "$ID_FILE" ]; then
        printf "%b\n" "[${YELLOW}FOUND${NC}] Identities discovered and saved to: ${GREEN}$ID_FILE${NC}"
        awk '{ printf "INSERT OR IGNORE INTO credentials (source_mac, credential_type, credential_value) VALUES (\047%s\047, \047identity\047, \047%s\047);\n", $1, $2 }' "$ID_FILE" >> "$credential_sql_file"
    else
        printf "%b\n" "[${GREEN}OK${NC}] No WPA-Enterprise identities found."
    fi
    
    if [ -s "$USER_FILE" ]; then
        printf "%b\n" "[${YELLOW}FOUND${NC}] Usernames discovered and saved to: ${GREEN}$USER_FILE${NC}"
        awk '{ printf "INSERT OR IGNORE INTO credentials (source_mac, credential_type, credential_value) VALUES (\047%s\047, \047username\047, \047%s\047);\n", $1, $2 }' "$USER_FILE" >> "$credential_sql_file"
    else
        printf "%b\n" "[${GREEN}OK${NC}] No WPA-Enterprise usernames found."
    fi

    if [ -s "$credential_sql_file" ] && [ -f "$DB_FILE" ]; then
        printf "Found credentials! Updating database...\n"
        sqlite3 "$DB_FILE" < "$credential_sql_file"
        printf "%b\n" "${GREEN}Database updated with PII.${NC}"
    fi
    rm -f "$credential_sql_file"
}

run_db() {
    shift
    if ! command -v xxd >/dev/null 2>&1; then
        printf "${RED}Error: 'xxd' is required for database operations but is not installed.${NC}\n"
        if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
            printf "Attempt to install it now via opkg? [y/N] "
            read -r response
            if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
                opkg update && opkg install xxd
                if ! command -v xxd >/dev/null 2>&1; then
                    printf "${RED}Installation failed. Please install 'xxd' manually.${NC}\n"
                    return 1
                fi
                printf "${GREEN}'xxd' installed successfully.${NC}\n"
            else
                return 1
            fi
        fi
    fi

    local files_to_process="$@"
    if [ -z "$files_to_process" ]; then files_to_process=$(find "$CAPTURE_DIR" -name "*.pcapng" 2>/dev/null); fi
    
    printf "%b\n" "${CYAN}--- Running Database Update (SQLite) ---${NC}"
    if ! command -v sqlite3 >/dev/null 2>&1; then printf "%b\n" "${RED}Error: sqlite3 not found!${NC}"; return 1; fi
    printf "Database located at: %b\n" "${GREEN}${DB_FILE}${NC}"

    initialize_database "sqlite3" "$DB_FILE"
    parse_and_update_from_live_log "sqlite3" "$DB_FILE"
    
    if [ -n "$files_to_process" ]; then
        local ALL_HASHES_FILE="$ANALYSIS_DIR/all_hashes_for_db.hc22000"
        run_with_spinner "Extracting hash data..." "hcxpcapngtool" $files_to_process -o "$ALL_HASHES_FILE"
        if [ -s "$ALL_HASHES_FILE" ]; then
            parse_and_update_db "sqlite3" "$ALL_HASHES_FILE"
            rm -f "$ALL_HASHES_FILE"
        else
            printf "${YELLOW}No new hash data found in pcap files.${NC}\n"
        fi
    else
        printf "${YELLOW}No pcap files specified or found to process for hash data.${NC}\n"
    fi
    printf "\n%b\n" "${GREEN}--- SQLite Update Complete ---${NC}"
}

run_filter_hashes() {
    shift
    local files_to_process="$@"
    if [ -z "$files_to_process" ]; then files_to_process=$(find "$ANALYSIS_DIR" -name "*.pcapng"); fi
    if [ -z "$files_to_process" ]; then printf "%b\n" "${RED}No .pcapng files found to process.${NC}"; return 1; fi
    
    local ALL_HASHES_FILE="$ANALYSIS_DIR/all_hashes.hc22000"; local FILTERED_HASHES_FILE="$ANALYSIS_DIR/filtered_hashes.hc22000"
    run_with_spinner "Extracting all hashes..." "hcxpcapngtool" $files_to_process -o "$ALL_HASHES_FILE"
    if [ ! -s "$ALL_HASHES_FILE" ]; then printf "%b\n" "${YELLOW}No hashes found.${NC}"; return; fi
    local HASHTOOL_CMD="hcxhashtool -i '$ALL_HASHES_FILE' -o '$FILTERED_HASHES_FILE'"
    if [ -n "$MAC_LIST" ]; then HASHTOOL_CMD="$HASHTOOL_CMD --mac-list='$(sanitize_arg "$MAC_LIST")'"; fi
    if [ -n "$MAC_SKIPLIST" ]; then HASHTOOL_CMD="$HASHTOOL_CMD --mac-skiplist='$(sanitize_arg "$MAC_SKIPLIST")'"; fi
    if [ -n "$ESSID_FILTER" ]; then HASHTOOL_CMD="$HASHTOOL_CMD --essid='$(sanitize_arg "$ESSID_FILTER")'"; fi
    if [ -n "$ESSID_REGEX" ]; then HASHTOOL_CMD="$HASHTOOL_CMD --essid-regex='$(sanitize_arg "$ESSID_REGEX")'"; fi
    if [ -n "$VENDOR_FILTER" ]; then HASHTOOL_CMD="$HASHTOOL_CMD --vendor='$(sanitize_arg "$VENDOR_FILTER")'"; fi
    if [ -n "$ESSID_MIN_LEN" ]; then HASHTOOL_CMD="$HASHTOOL_CMD --essid-min='$(sanitize_arg "$ESSID_MIN_LEN")'"; fi
    if [ -n "$ESSID_MAX_LEN" ]; then HASHTOOL_CMD="$HASHTOOL_CMD --essid-max='$(sanitize_arg "$ESSID_MAX_LEN")'"; fi
    if [ -n "$HASH_TYPE" ]; then HASHTOOL_CMD="$HASHTOOL_CMD --type='$(sanitize_arg "$HASH_TYPE")'"; fi
    if [ "$AUTHORIZED_ONLY" -eq 1 ]; then HASHTOOL_CMD="$HASHTOOL_CMD --authorized"; fi
    if [ "$CHALLENGE_ONLY" -eq 1 ]; then HASHTOOL_CMD="$HASHTOOL_CMD --challenge"; fi
    run_with_spinner "Running filter command..." "$HASHTOOL_CMD"
    if [ -s "$FILTERED_HASHES_FILE" ]; then echo "Filtered hash file saved to: $FILTERED_HASHES_FILE"; else printf "%b\n" "${YELLOW}No hashes matched criteria.${NC}"; fi
}

run_generate_wordlist() {
    shift
    local files_to_process="$@"
    if [ -z "$files_to_process" ]; then files_to_process=$(find "$ANALYSIS_DIR" -name "*.pcapng"); fi
    if [ -z "$files_to_process" ]; then printf "%b\n" "${RED}No .pcapng files found to process.${NC}"; return 1; fi
    
    run_with_spinner "Extracting ESSIDs..." "hcxpcapngtool" $files_to_process -E "$ANALYSIS_DIR/all_essids.txt"
    if [ ! -s "$ANALYSIS_DIR/all_essids.txt" ]; then printf "%b\n" "${YELLOW}No ESSIDs found.${NC}"; return; fi
    run_with_spinner "Generating wordlist..." "hcxeiutool" -i "$ANALYSIS_DIR/all_essids.txt" -s "$ANALYSIS_DIR/candidate-wordlist.txt"
    if [ -s "$ANALYSIS_DIR/candidate-wordlist.txt" ]; then echo "Generated wordlist saved to: $ANALYSIS_DIR/candidate-wordlist.txt"; fi
}

run_merge_hashes() {
    shift
    local files_to_process="$@"
    if [ -z "$files_to_process" ]; then files_to_process=$(find "$ANALYSIS_DIR" -name "*.hc22000"); fi
    if [ -z "$files_to_process" ]; then printf "%b\n" "${RED}No .hc22000 files found to process.${NC}"; return 1; fi
    
    if [ "$(echo "$files_to_process" | wc -w)" -lt 2 ]; then printf "%b\n" "${RED}Error: Need at least two .hc22000 files to merge.${NC}"; return; fi
    local MERGED_HASH_FILE="$ANALYSIS_DIR/merged_hashes.hc22000"; local temp_merged="/tmp/temp_merged.hc22000"
    local first_file=$(echo "$files_to_process" | head -n 1)
    cp "$first_file" "$temp_merged"
    echo "$files_to_process" | tail -n +2 | while read -r file; do
        hcxessidtool --pmkid1="$temp_merged" --pmkid2="$file" --pmkidout12="$MERGED_HASH_FILE" >/dev/null 2>&1
        mv "$MERGED_HASH_FILE" "$temp_merged"
    done
    mv "$temp_merged" "$MERGED_HASH_FILE"; echo "Merged hash file saved to: $MERGED_HASH_FILE"
}

run_export() {
    shift
    local files_to_process="$@"
    if [ -z "$files_to_process" ]; then files_to_process=$(find "$ANALYSIS_DIR" -name "*.pcapng"); fi
    if [ -z "$files_to_process" ]; then printf "%b\n" "${RED}No .pcapng files found to process.${NC}"; return 1; fi
    
    local ALL_HASHES_FILE="$ANALYSIS_DIR/all_hashes.hc22000"
    run_with_spinner "Extracting hashes..." "hcxpcapngtool" $files_to_process -o "$ALL_HASHES_FILE"
    if [ ! -s "$ALL_HASHES_FILE" ]; then printf "%b\n" "${YELLOW}No hashes found.${NC}"; return; fi
    printf "\n%b\n" "${BLUE}--- Exporting to .cap Format ---${NC}"
    run_with_spinner "Converting to .cap..." "hcxhash2cap" -c "$ANALYSIS_DIR/legacy_captures.cap" --pmkid-eapol="$ALL_HASHES_FILE"
    echo "Legacy .cap file saved to: $ANALYSIS_DIR/legacy_captures.cap"
    printf "\n%b\n" "${BLUE}--- Exporting to CSV ---${NC}"
    run_with_spinner "Converting to .csv..." "hcxpcapngtool" $files_to_process --csv="$ANALYSIS_DIR/networks_summary.csv"
    echo "Network summary saved to: $ANALYSIS_DIR/networks_summary.csv"
}

run_geotrack() {
    shift
    local files_to_process="$@"
    if [ -z "$files_to_process" ]; then files_to_process=$(find "$ANALYSIS_DIR" -name "*.nmea"); fi
    if [ -z "$files_to_process" ]; then printf "%b\n" "${RED}No .nmea files found to process.${NC}"; return 1; fi
    
    if ! command -v gpsbabel >/dev/null 2>&1; then printf "%b\n" "${RED}Error: gpsbabel is not installed.${NC}"; return; fi
    local KML_FILE="$ANALYSIS_DIR/wardriving_track.kml"; local temp_combined_nmea="/tmp/combined_nmea.tmp"; >"$temp_combined_nmea"
    echo "$files_to_process" | while read -r f; do cat "$f" >> "$temp_combined_nmea"; done
    if [ ! -s "$temp_combined_nmea" ]; then printf "%b\n" "${YELLOW}No .nmea data found.${NC}"; return; fi
    run_with_spinner "Converting NMEA to KML..." "gpsbabel" -w -t -i nmea -f "$temp_combined_nmea" -o kml -F "$KML_FILE"
    rm -f "$temp_combined_nmea"; echo "KML track file saved to: $KML_FILE"
}

send_notification() {
    # Exit if notifications are disabled or the URL is not set
    if [ "$NOTIFICATION_ENABLED" -ne 1 ] || [ -z "$NOTIFICATION_URL" ]; then
        return
    fi
    
    # Check for wget or curl
    if ! command -v wget >/dev/null 2>&1; then
        printf "%b\n" "${YELLOW}Warning: 'wget' is required for notifications but is not installed.${NC}"
        return
    fi

    local title="$1"
    local message="$2"
    
    printf "Sending notification via ${NOTIFICATION_SERVICE}...\n"

    case "$NOTIFICATION_SERVICE" in
        "ntfy")
            # ntfy.sh is simple. It uses the message body and a title header.
            wget -q -O /dev/null --post-data="$message" --header="Title: $title" --header="Tags: tada" "$NOTIFICATION_URL"
            ;;
        "discord")
            # Discord uses a JSON payload with an "embeds" object for nice formatting.
            # We need to escape special JSON characters from the message.
            local sanitized_message
            sanitized_message=$(echo "$message" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed 's/`/\\`/g' | sed -z 's/\n/\\n/g')
            
            local json_payload
            json_payload=$(printf '{"username": "HCX Analyzer", "embeds": [{"title": "%s", "description": "```\n%s\n```", "color": 5814783}]}' "$title" "$sanitized_message")
            
            wget -q -O /dev/null --post-data="$json_payload" --header="Content-Type: application/json" "$NOTIFICATION_URL"
            ;;
        *)
            printf "%b\n" "${YELLOW}Warning: Unknown notification service '$NOTIFICATION_SERVICE'.${NC}"
            ;;
    esac
}

run_remote_crack_monitor() {
    local remote_potfile="$1"
    local local_hash_file="$2"
    local temp_potfile="/tmp/analyzer_remote.pot"

    printf "\n%b\n" "${BLUE}--- Monitoring Remote Session (Ctrl+C to stop) ---${NC}"

    local previous_hash
    previous_hash=$(ssh "${REMOTE_SERVER_USER}@${REMOTE_SERVER_HOST}" "md5sum '$remote_potfile' 2>/dev/null | cut -d' ' -f1")

    trap 'printf "\nMonitoring stopped by user.\n"; rm -f "$temp_potfile"; exit 0' INT TERM

    while true; do
        sleep 120

        local current_hash
        current_hash=$(ssh "${REMOTE_SERVER_USER}@${REMOTE_SERVER_HOST}" "md5sum '$remote_potfile' 2>/dev/null | cut -d' ' -f1")

        if [ "$current_hash" != "$previous_hash" ] && [ -n "$current_hash" ]; then
            printf "\n%b [%s]\n" "${YELLOW}🎉 New cracked passwords detected! Retrieving results...${NC}" "$(date '+%Y-%m-%d %H:%M:%S')"
            
            if ! scp -q "${REMOTE_SERVER_USER}@${REMOTE_SERVER_HOST}:${remote_potfile}" "$temp_potfile"; then
                printf "%b\n" "${RED}Error: Failed to download updated potfile.${NC}"
                continue
            fi

            # Capture the output of hashcat --show into a variable
            local cracked_output
            cracked_output=$(hashcat --show -m 22000 "$local_hash_file" --potfile-path "$temp_potfile")

            printf "%b\n" "${GREEN}--- Cracked Hashes So Far ---${NC}"
            echo "$cracked_output" # Display the output on the console
            printf "%b\n" "${GREEN}-----------------------------${NC}"

            # --- TRIGGER NOTIFICATION ---
            # Send the captured output as a notification
            send_notification "HCX Cracked Passwords!" "$cracked_output"

            previous_hash="$current_hash"
            printf "\n%b" "Monitoring... (Ctrl+C to stop)"
        else
            printf "."
        fi
    done
}

run_generate_dashboard() {
    shift
    local files_to_process="$@"
    if [ -z "$files_to_process" ]; then files_to_process=$(find "$CAPTURE_DIR" -name "*.pcapng" 2>/dev/null); fi
    if [ -z "$files_to_process" ]; then printf "%b\n" "${RED}No .pcapng files found to process.${NC}"; return 1; fi

    printf "%b\n" "${CYAN}--- 📊 Generating HTML Dashboard ---${NC}"

    # --- Step 1: Data Gathering ---
    local TEMP_DIR="/tmp/dashboard_data_$$"
    mkdir -p "$TEMP_DIR"
    local ALL_HASHES_FILE="$TEMP_DIR/all_hashes.hc22000"
    local NETWORKS_CSV_FILE="$TEMP_DIR/networks.csv"
    local ID_FILE="$TEMP_DIR/identities.txt"
    local USER_FILE="$TEMP_DIR/usernames.txt"
    local NMEA_FILE="$TEMP_DIR/track.nmea"
    local CRACKED_FILE="$TEMP_DIR/cracked_by_defaults.txt"
    local DASHBOARD_FILE="$ANALYSIS_DIR/dashboard.html"
    
    run_with_spinner "Extracting all data from pcapng files..." "hcxpcapngtool" $files_to_process -o "$ALL_HASHES_FILE" --csv="$NETWORKS_CSV_FILE" -I "$ID_FILE" -U "$USER_FILE" --nmea="$NMEA_FILE"

    run_with_spinner "Checking for default and weak passwords..." "hcxpsktool" -c "$ALL_HASHES_FILE" --netgear --spectrum --weakpass --digit10 --phome --tenda --ee --alticeoptimum --asus --eudate --usdate --wpskeys > "$CRACKED_FILE"

    # --- Step 2: Data Processing & Variable Preparation ---
    printf "Processing collected data...\n"
    
    # Process summary stats
    local TOTAL_NETWORKS=0; if [ -f "$NETWORKS_CSV_FILE" ]; then TOTAL_NETWORKS=$(tail -n +2 "$NETWORKS_CSV_FILE" | wc -l); fi
    local TOTAL_HASHES=0; if [ -f "$ALL_HASHES_FILE" ]; then TOTAL_HASHES=$(wc -l < "$ALL_HASHES_FILE"); fi
    local TOTAL_CRACKED=0; if [ -f "$CRACKED_FILE" ]; then TOTAL_CRACKED=$(wc -l < "$CRACKED_FILE"); fi
    local TOTAL_PII=0; if [ -f "$ID_FILE" ]; then TOTAL_PII=$((TOTAL_PII + $(wc -l < "$ID_FILE"))); fi
    if [ -f "$USER_FILE" ]; then TOTAL_PII=$((TOTAL_PII + $(wc -l < "$USER_FILE"))); fi
    
    # Process networks table
    local NETWORKS_TABLE_ROWS=""
    if [ -f "$NETWORKS_CSV_FILE" ]; then
        tail -n +2 "$NETWORKS_CSV_FILE" | while IFS=, read -r bssid essid enc vendor; do
            # Sanitize for HTML
            essid=$(echo "$essid" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
            vendor=$(echo "$vendor" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
            NETWORKS_TABLE_ROWS="${NETWORKS_TABLE_ROWS}<tr><td>${bssid}</td><td>${essid}</td><td>${enc}</td><td>${vendor}</td></tr>"
        done
    fi

    # Process cracked passwords table
    local CRACKED_TABLE_ROWS=""
    if [ -f "$CRACKED_FILE" ]; then
        while IFS=: read -r bssid client psk essid; do
            psk=$(echo "$psk" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
            essid=$(echo "$essid" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
            CRACKED_TABLE_ROWS="${CRACKED_TABLE_ROWS}<tr><td class='monospace'>${bssid}</td><td>${essid}</td><td class='monospace strong'>${psk}</td></tr>"
        done < "$CRACKED_FILE"
    fi
    
    # Process PII tables
    local PII_ID_ROWS=""; local PII_USER_ROWS=""
    if [ -f "$ID_FILE" ]; then
        while read -r mac identity; do PII_ID_ROWS="${PII_ID_ROWS}<tr><td class='monospace'>${mac}</td><td>${identity}</td></tr>"; done < "$ID_FILE"
    fi
    if [ -f "$USER_FILE" ]; then
        while read -r mac user; do PII_USER_ROWS="${PII_USER_ROWS}<tr><td class='monospace'>${mac}</td><td>${user}</td></tr>"; done < "$USER_FILE"
    fi
    
    # Process GPS data
    local GEOJSON_DATA="null"
    if [ -s "$NMEA_FILE" ] && command -v gpsbabel >/dev/null 2>&1; then
        printf "Processing GPS data for map...\n"
        local GEOJSON_FILE="$TEMP_DIR/track.geojson"
        if gpsbabel -w -t -i nmea -f "$NMEA_FILE" -o geojson -F "$GEOJSON_FILE" >/dev/null 2>&1; then
            GEOJSON_DATA=$(cat "$GEOJSON_FILE")
        fi
    fi

    # --- Step 3: HTML Generation ---
    printf "Generating self-contained HTML file...\n"
    
    # Use a Here Document to create the HTML file. This is much cleaner than multiple echo statements.
    cat <<EOF > "$DASHBOARD_FILE"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-g">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>HCX-Analyzer Report</title>
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin=""/>
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
    <style>
        :root {
            --bg-color: #1a1a1a; --text-color: #e0e0e0; --header-bg: #2c2c2c; --table-bg: #252525;
            --border-color: #444; --accent-color: #00aaff; --green-color: #00ffaa; --yellow-color: #ffaa00;
        }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; 
               background-color: var(--bg-color); color: var(--text-color); margin: 0; padding: 20px; line-height: 1.6; }
        .container { max-width: 1200px; margin: 0 auto; }
        header { background-color: var(--header-bg); padding: 20px; border-radius: 8px; margin-bottom: 20px; border: 1px solid var(--border-color); }
        header h1 { margin: 0; color: var(--accent-color); }
        .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .stat-card { background-color: var(--table-bg); padding: 20px; border-radius: 8px; text-align: center; border: 1px solid var(--border-color); }
        .stat-card .value { font-size: 2.5em; font-weight: bold; color: var(--green-color); }
        .stat-card .label { font-size: 1.1em; color: var(--text-color); }
        .section { background-color: var(--header-bg); padding: 20px; border-radius: 8px; margin-bottom: 20px; border: 1px solid var(--border-color); }
        .section h2 { margin-top: 0; border-bottom: 2px solid var(--accent-color); padding-bottom: 10px; }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid var(--border-color); }
        th { background-color: var(--table-bg); }
        tr:hover { background-color: #333; }
        .monospace { font-family: "SF Mono", "Menlo", "Monaco", monospace; }
        .strong { font-weight: bold; color: var(--yellow-color); }
        #map { height: 500px; border-radius: 8px; border: 1px solid var(--border-color); }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>HCX-Analyzer Dashboard</h1>
            <p>Report generated on: $(date)</p>
        </header>

        <div class="stats-grid">
            <div class="stat-card"><div class="value">${TOTAL_NETWORKS}</div><div class="label">Networks</div></div>
            <div class="stat-card"><div class="value">${TOTAL_HASHES}</div><div class="label">Total Hashes</div></div>
            <div class="stat-card"><div class="value">${TOTAL_CRACKED}</div><div class="label">Cracked by Defaults</div></div>
            <div class="stat-card"><div class="value">${TOTAL_PII}</div><div class="label">PII Found</div></div>
        </div>

        <div class="section">
            <h2><span class="monospace strong">🔑</span> Cracked Passwords</h2>
            <table>
                <thead><tr><th>BSSID</th><th>ESSID</th><th>Password (PSK)</th></tr></thead>
                <tbody>${CRACKED_TABLE_ROWS:-"<tr><td colspan='3'>No default passwords found.</td></tr>"}</tbody>
            </table>
        </div>

        <div class="section">
            <h2>🗺️ GPS Wardriving Map</h2>
            <div id="map"></div>
        </div>
        
        <div class="section">
            <h2><span class="monospace">📶</span> Discovered Networks</h2>
            <table>
                <thead><tr><th>BSSID</th><th>ESSID</th><th>Encryption</th><th>Vendor</th></tr></thead>
                <tbody>${NETWORKS_TABLE_ROWS:-"<tr><td colspan='4'>No networks found.</td></tr>"}</tbody>
            </table>
        </div>
        
        <div class="section">
            <h2><span class="monospace">👤</span> Personally Identifiable Information (PII)</h2>
            <h3>Enterprise Identities</h3>
            <table>
                <thead><tr><th>Source MAC</th><th>Identity</th></tr></thead>
                <tbody>${PII_ID_ROWS:-"<tr><td colspan='2'>No identities found.</td></tr>"}</tbody>
            </table>
            <h3 style="margin-top:20px;">Enterprise Usernames</h3>
            <table>
                <thead><tr><th>Source MAC</th><th>Username</th></tr></thead>
                <tbody>${PII_USER_ROWS:-"<tr><td colspan='2'>No usernames found.</td></tr>"}</tbody>
            </table>
        </div>
    </div>

    <script>
        const geoJsonData = ${GEOJSON_DATA};
        const mapElement = document.getElementById('map');
        
        if (geoJsonData && geoJsonData.features && geoJsonData.features.length > 0) {
            // Use the first coordinate of the first feature as the initial center of the map
            const initialCoords = geoJsonData.features[0].geometry.coordinates[0];
            const map = L.map('map').setView([initialCoords[1], initialCoords[0]], 14);

            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
            }).addTo(map);

            const trackStyle = { "color": "#00aaff", "weight": 5, "opacity": 0.8 };
            const geoJsonLayer = L.geoJSON(geoJsonData, { style: trackStyle }).addTo(map);
            
            // Fit the map view to the bounds of the entire track
            map.fitBounds(geoJsonLayer.getBounds());
        } else {
            mapElement.innerHTML = '<p style="text-align:center; padding: 20px;">No GPS data found to display map. Install gpsbabel and ensure captures have NMEA data.</p>';
            mapElement.style.height = 'auto';
        }
    </script>
</body>
</html>
EOF

    # --- Step 4: Cleanup ---
    rm -rf "$TEMP_DIR"
    printf "\n%b\n" "${GREEN}--- ✅ Dashboard Complete ---${NC}"
    printf "Report saved to: %s\n" "${BLUE}${DASHBOARD_FILE}${NC}"
}

run_remote_crack() {
    shift
    local files_to_process="$@"
    if [ -z "$files_to_process" ]; then files_to_process=$(find "$ANALYSIS_DIR" -name "*.pcapng"); fi
    if [ -z "$files_to_process" ]; then printf "%b\n" "${RED}No .pcapng files found to process.${NC}"; return 1; fi
    
    if [ "$REMOTE_SERVER_ENABLED" -eq 0 ]; then printf "%b\n" "${YELLOW}Remote cracking is disabled.${NC}"; return; fi
    local ALL_HASHES_FILE="$ANALYSIS_DIR/all_hashes.hc22000"
    run_with_spinner "Extracting hashes..." "hcxpcapngtool" $files_to_process -o "$ALL_HASHES_FILE"
    if [ ! -s "$ALL_HASHES_FILE" ]; then printf "%b\n" "${YELLOW}No hashes found to crack.${NC}"; return; fi
    
    run_with_spinner "Preparing remote crack directory..." "ssh" "${REMOTE_SERVER_USER}@${REMOTE_SERVER_HOST}" "mkdir -p $REMOTE_CAPTURE_PATH" || return 1
    
    printf "%b\n" "You are about to send hashes to ${GREEN}\"${REMOTE_SERVER_USER}\"@${REMOTE_SERVER_HOST}${NC} for cracking."
    printf "Are you sure? [y/N] "; read -r response
    if ! (echo "$response" | grep -qE '^[yY]([eE][sS])?$'); then echo "Cancelled."; return; fi
    run_with_spinner "Uploading hash file..." "scp" "$ALL_HASHES_FILE" "${REMOTE_SERVER_USER}@${REMOTE_SERVER_HOST}:${REMOTE_CAPTURE_PATH}/" || return 1
    
    local remote_hash_file="${REMOTE_CAPTURE_PATH}/$(basename "$ALL_HASHES_FILE")"
    local remote_potfile="${REMOTE_CAPTURE_PATH}/cracked.pot"
    local HASHCAT_CMD="'$REMOTE_HASHCAT_PATH' -m 22000 '$remote_hash_file' '$REMOTE_WORDLIST_PATH' --potfile-path '$remote_potfile'"
    
    printf "\n%b\n" "${BLUE}--- Starting Remote Hashcat Session ---${NC}"
    ssh "${REMOTE_SERVER_USER}@${REMOTE_SERVER_HOST}" "nohup sh -c \"${HASHCAT_CMD}\" > /dev/null 2>&1 &" || { printf "%b\n" "${RED}SSH command failed.${NC}"; return 1; }
    
    # This is the new logic block
    if [ "$MONITOR_CRACK" -eq 1 ]; then
        # Call the new monitoring function
        run_remote_crack_monitor "$remote_potfile" "$ALL_HASHES_FILE"
    else
        # This is the original behavior for non-monitored sessions
        printf "\n%b\n" "${GREEN}--- Remote Cracking Session Started! ---${NC}"
        printf "To retrieve cracked passwords manually, run:\n"
        printf "%b\n" "${CYAN}scp \"${REMOTE_SERVER_USER}@${REMOTE_SERVER_HOST}:${remote_potfile}\" . && hashcat --show -m 22000 ${ALL_HASHES_FILE} --potfile-path cracked.pot${NC}"
    fi
}

#==============================================================================
# DATABASE & REMOTE EXECUTION
#==============================================================================

run_mysql() {
    shift
    local files_to_process="$@"
    if [ -z "$files_to_process" ]; then files_to_process=$(find "$ANALYSIS_DIR" -name "*.pcapng"); fi
    if [ -z "$files_to_process" ]; then printf "%b\n" "${RED}No .pcapng files found to process.${NC}"; return 1; fi
    
    local ALL_HASHES_FILE="$ANALYSIS_DIR/all_hashes_for_db.hc22000"
    printf "%b\n" "${CYAN}--- Running Database Update (MySQL) ---${NC}"
    run_with_spinner "Extracting data..." "hcxpcapngtool" $files_to_process -o "$ALL_HASHES_FILE"
    if [ ! -s "$ALL_HASHES_FILE" ]; then printf "%b\n" "${YELLOW}No new data found.${NC}"; return; fi
    parse_and_update_db "mysql" "$ALL_HASHES_FILE"; rm -f "$ALL_HASHES_FILE"
    printf "\n%b\n" "${GREEN}--- MySQL Update Complete ---${NC}"
}

run_remote_execution() {
    local action_type="$1"; local action_name="$2"; shift 2
    printf "%b\n" "${CYAN}--- Initiating Remote Execution: ${action_type} -> ${action_name} ---${NC}"
    if [ "$REMOTE_SERVER_ENABLED" -eq 0 ]; then printf "%b\n" "${RED}Remote execution is disabled.${NC}"; return 1; fi
    if [ "$#" -eq 0 ]; then
        printf "%b\n" "${YELLOW}No files specified for remote execution.${NC}"; return 1
    fi

    printf "Files to be uploaded:\n"
    # Loop through each file to get its size and format the output
    for file in "$@"; do
        # Get file size in kilobytes in a POSIX-compliant way
        size_kb=$(du -k "$file" | cut -f1)

        # Check if size is greater than 1MB (1024 KB)
        if [ "$size_kb" -gt 1024 ]; then
            # Use awk for floating-point math to calculate MB
            size_formatted=$(awk -v kb="$size_kb" 'BEGIN { printf "%.1f MB", kb / 1024 }')
        else
            size_formatted="${size_kb} KB"
        fi

        # Print the file path and the formatted size in neat columns
        printf "  %-70s %s\n" "$file" "$size_formatted"
    done
    
    printf "\n%b\n" "${BLUE}--- Preparing Remote Environment ---${NC}"
    run_with_spinner "Preparing remote directory..." "ssh" "${REMOTE_SERVER_USER}@${REMOTE_SERVER_HOST}" "mkdir -p '${REMOTE_SERVER_TMP_PATH}'" || return 1
    
    run_with_spinner "Uploading files..." "scp" -q -r -- "$@" "${REMOTE_SERVER_USER}@${REMOTE_SERVER_HOST}:${REMOTE_SERVER_TMP_PATH}/" || return 1
    
    local remote_script_path="$REMOTE_SERVER_TMP_PATH/remote_job.sh"; local local_db_path=""
    if [ "$action_name" = "db" ]; then
        # NEW: Create a blank DB file if it doesn't exist locally first.
        if [ ! -f "$DB_FILE" ]; then
            printf "\nLocal database not found. Creating a new one for the remote session..."
            touch "$DB_FILE"
            printf "${GREEN}Done.${NC}\n"
        fi
        run_with_spinner "Uploading local SQLite DB..." "scp" -q "$DB_FILE" "${REMOTE_SERVER_USER}@${REMOTE_SERVER_HOST}:${REMOTE_SERVER_TMP_PATH}/database.db" || return 1
        local_db_path="$REMOTE_SERVER_TMP_PATH/database.db"
    fi
    
        local function_definitions=""
        local required_funcs="sanitize_arg run_with_spinner run_summary run_intel run_vuln run_pii run_db run_mysql parse_and_update_db run_filter_hashes run_generate_wordlist run_merge_hashes run_export run_geotrack run_health_check version_ge run_interactive_mode initialize_database parse_and_update_from_live_log"
        for func in $required_funcs; do
            # This is the corrected line that allows for spaces/tabs before a function name
            func_def=$(sed -n "/^[[:space:]]*${func}() {/,/^\}/p" "$0")
            function_definitions="$function_definitions
$func_def"
        done
    
    REMOTE_SCRIPT=$(cat <<EOF
#!/bin/sh
action_name='$action_name'
export NC='\\033[0m' GREEN='\\033[0;32m' YELLOW='\\033[1;33m' CYAN='\\033[0;36m' BLUE='\\033[0;34m' RED='\\033[0;31m'
export ANALYSIS_DIR="$REMOTE_SERVER_TMP_PATH"; export CAPTURE_DIR="$REMOTE_SERVER_TMP_PATH"; export DB_FILE="$local_db_path"
export DB_HOST='$(sanitize_arg "$DB_HOST")'; export DB_USER='$(sanitize_arg "$DB_USER")'; export DB_PASS='$(sanitize_arg "$DB_PASS")'; export DB_NAME='$(sanitize_arg "$DB_NAME")'
export VERBOSE=$VERBOSE; export MAC_LIST='$(sanitize_arg "$MAC_LIST")'; export MAC_SKIPLIST='$(sanitize_arg "$MAC_SKIPLIST")'
export ESSID_FILTER='$(sanitize_arg "$ESSID_FILTER")'; export VENDOR_FILTER='$(sanitize_arg "$VENDOR_FILTER")'
export ESSID_MIN_LEN='$(sanitize_arg "$ESSID_MIN_LEN")'; export ESSID_MAX_LEN='$(sanitize_arg "$ESSID_MAX_LEN")'; export HASH_TYPE='$(sanitize_arg "$HASH_TYPE")'
export ESSID_REGEX='$(sanitize_arg "$ESSID_REGEX")'; export AUTHORIZED_ONLY=$AUTHORIZED_ONLY; export CHALLENGE_ONLY=$CHALLENGE_ONLY
export SUMMARY_MODE='$(sanitize_arg "$SUMMARY_MODE")'

$function_definitions

printf "%b\\n" "\${CYAN}--- Remote Job Started: \${action_name} ---"
if [ "\$action_name" = "interactive" ]; then run_interactive_mode "remote"; else run_\${action_name} "remote"; fi
printf "%b\\n" "\${GREEN}--- Remote Job Finished ---\${NC}"
EOF
)
    echo "$REMOTE_SCRIPT" | ssh "${REMOTE_SERVER_USER}@${REMOTE_SERVER_HOST}" "cat > '$remote_script_path' && chmod +x '$remote_script_path'"
    
    printf "\n%b\n" "${BLUE}--- Executing Remote Job ---${NC}"; ssh -T "${REMOTE_SERVER_USER}@${REMOTE_SERVER_HOST}" "'$remote_script_path'"; local ssh_exit_code=$?
    printf "%b\n" "${BLUE}--- Remote Execution Complete ---${NC}"

    if [ $ssh_exit_code -eq 0 ]; then
        printf "%b\n" "${GREEN}Remote job finished successfully.${NC}"

        if [ "$action_type" = "utility" ] || { [ "$action_type" = "mode" ] && [ "$action_name" != "db" ] && [ "$action_name" != "mysql" ] && [ "$action_name" != "interactive" ]; }; then
            local remote_archive="${REMOTE_SERVER_TMP_PATH}/results.tar"
            local local_archive="/tmp/results.tar"

            local archive_cmd="tar -cf '${remote_archive}' --exclude='remote_job.sh' -C '${REMOTE_SERVER_TMP_PATH}' ."
            run_with_spinner "Archiving remote results..." \
                "ssh" "${REMOTE_SERVER_USER}@${REMOTE_SERVER_HOST}" "$archive_cmd"

            if ssh -T "${REMOTE_SERVER_USER}@${REMOTE_SERVER_HOST}" "[ -s '${remote_archive}' ]"; then
                printf "Downloading results..."
                if scp "${REMOTE_SERVER_USER}@${REMOTE_SERVER_HOST}:${remote_archive}" "${local_archive}"; then
                    printf " ${GREEN}Done.${NC}\n"
                    
                    run_with_spinner "Extracting results locally..." \
                        "tar" -xf "${local_archive}" -C "${ANALYSIS_DIR}"
                    rm -f "${local_archive}"
                    printf "%b\n" "Results successfully transferred back to the Pineapple: ${GREEN}${ANALYSIS_DIR}/${NC}"
                else
                    printf " ${RED}Failed.${NC}\n"
                    printf "%b\n" "${RED}Could not download results archive from remote host.${NC}"
                fi
            else
                printf "%b\n" "${RED}Failed to create or find results archive on remote host.${NC}"
                printf "%b\n" "${CYAN}Listing remote directory for debugging:${NC}"
                ssh -T "${REMOTE_SERVER_USER}@${REMOTE_SERVER_HOST}" "ls -la '${REMOTE_SERVER_TMP_PATH}'"
            fi
        elif [ "$action_name" = "db" ]; then
            run_with_spinner "Downloading updated SQLite DB..." "scp" -q "${REMOTE_SERVER_USER}@${REMOTE_SERVER_HOST}:${local_db_path}" "$DB_FILE"
        fi
    else
        printf "%b\n" "${RED}Remote script exited with an error (Code: $ssh_exit_code). Results may not be complete.${NC}"
    fi

    run_with_spinner "Cleaning up remote session files..." \
        "ssh" "${REMOTE_SERVER_USER}@${REMOTE_SERVER_HOST}" "rm -rf '${REMOTE_SERVER_TMP_PATH}'"
}


#==============================================================================
# SCRIPT EXECUTION LOGIC
#==============================================================================

run_cloud_sync() {
    printf "\n%b\n" "${BLUE}--- ☁️ Cloud Storage Synchronization ---${NC}"

    # --- Step 1: Check Dependencies & Configuration ---
    if [ "$CLOUD_SYNC_ENABLED" -ne 1 ]; then
        printf "%b\n" "${YELLOW}Cloud sync is disabled in the configuration file.${NC}"
        return 1
    fi
    if ! command -v rclone >/dev/null 2>&1; then
        printf "%b\n" "${RED}Error: 'rclone' is required but not installed. Please run 'opkg install rclone'.${NC}"
        return 1
    fi
    if [ -z "$RCLONE_REMOTE_NAME" ]; then
        printf "%b\n" "${RED}Error: RCLONE_REMOTE_NAME is not set in your config file.${NC}"
        printf "Please run 'rclone config' to set up a remote and add its name to the config.\n"
        return 1
    fi

    local remote_full_path="${RCLONE_REMOTE_NAME}:${RCLONE_REMOTE_PATH}"

    # --- Step 2: Upload New Files ---
    printf "\n%b\n" "${CYAN}--- Uploading Local Files to ${remote_full_path} ---${NC}"
    
    printf "Uploading new captures from %s...\n" "$CAPTURE_DIR"
    rclone copy "$CAPTURE_DIR" "${remote_full_path}/captures/" --include="*.pcapng" --progress
    
    printf "\nUploading analysis results from %s...\n" "$ANALYSIS_DIR"
    rclone copy "$ANALYSIS_DIR" "${remote_full_path}/analysis/" --include="*.{txt,csv,kml,hc22000,html}" --progress
    
    # --- Step 3: Download Remote Results ---
    printf "\n%b\n" "${CYAN}--- Downloading Remote Files from ${remote_full_path} ---${NC}"
    printf "Syncing remote potfile to local analysis directory...\n"
    # Use 'copy' to ensure we get the latest version from the cloud without deleting local files.
    rclone copy "${remote_full_path}/results/" "$ANALYSIS_DIR/" --include="*.pot" --progress

    printf "\n%b\n" "${GREEN}--- ✅ Cloud Sync Complete ---${NC}"
}

run_setup_remote() {
    printf "\n%b\n" "${CYAN}--- Interactive Remote Server Setup Wizard ---${NC}"
    printf "This wizard will help you configure a remote server for analysis and cracking.\n"
    printf "It will guide you through setting up passwordless SSH access and checking dependencies.\n\n"

    # --- Step 1: Gather User Input ---
    local remote_user
    local remote_host
    printf "%b" "Please enter the username for the remote server (e.g., root, user): "
    read -r remote_user
    if [ -z "$remote_user" ]; then printf "\n%b\n" "${RED}Username cannot be empty. Aborting.${NC}"; return 1; fi

    printf "%b" "Please enter the IP address or hostname of the remote server: "
    read -r remote_host
    if [ -z "$remote_host" ]; then printf "\n%b\n" "${RED}Hostname cannot be empty. Aborting.${NC}"; return 1; fi
    
    printf "\n%b\n" "${BLUE}--- Step 2: Configure SSH Access ---${NC}"
    
    # Check for local SSH key
    if [ ! -f "$HOME/.ssh/id_rsa" ]; then
        printf "%b\n" "${YELLOW}No local SSH key found.${NC}"
        printf "An SSH key is required for passwordless login. Shall I generate one now? [y/N] "
        read -r response
        if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
            printf "Generating SSH key...\n"
            ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/id_rsa" -N ""
        else
            printf "%b\n" "${RED}SSH key is required to proceed. Aborting.${NC}"
            return 1
        fi
    fi

    # Copy public key to remote server
    printf "\nTo enable passwordless access, I need to copy your public SSH key to the remote server.\n"
    printf "You will be prompted for '${YELLOW}${remote_user}@${remote_host}${NC}'s' password ${RED}one last time${NC}.\n"
    if ! ssh-copy-id "${remote_user}@${remote_host}"; then
        printf "\n%b\n" "${RED}Failed to copy SSH key. Please check your username, host, and password. Aborting.${NC}"
        return 1
    fi
    
    printf "\n%b\n" "${GREEN}SSH key successfully copied!${NC}"
    printf "Testing passwordless connection... "
    if ssh -o 'BatchMode=yes' -o 'ConnectTimeout=5' "${remote_user}@${remote_host}" 'echo "Success"' >/dev/null 2>&1; then
        printf "%b\n" "${GREEN}OK${NC}"
    else
        printf "\n%b\n" "${RED}Failed to establish a passwordless connection. Aborting.${NC}"
        return 1
    fi

    # --- Step 3: Check Remote Dependencies ---
    printf "\n%b\n" "${BLUE}--- Step 3: Check Remote Dependencies ---${NC}"
    local hcx_ok=0
    local hashcat_ok=0
    printf "Checking for hcxtools... "
    if ssh "${remote_user}@${remote_host}" 'command -v hcxpcapngtool' >/dev/null 2>&1; then
        printf "%b\n" "${GREEN}Found${NC}"; hcx_ok=1
    else
        printf "%b\n" "${RED}Not Found${NC}"
    fi
    printf "Checking for hashcat... "
    if ssh "${remote_user}@${remote_host}" 'command -v hashcat' >/dev/null 2>&1; then
        printf "%b\n" "${GREEN}Found${NC}"; hashcat_ok=1
    else
        printf "%b\n" "${RED}Not Found${NC}"
    fi

    # --- Step 4: Attempt to Install Missing Dependencies ---
    if [ "$hcx_ok" -eq 0 ] || [ "$hashcat_ok" -eq 0 ]; then
        printf "\n%b\n" "${YELLOW}One or more dependencies are missing.${NC}"
        printf "Shall I attempt to install them automatically? (This may require sudo password on the remote machine) [y/N] "
        read -r install_response
        if [ "$install_response" = "y" ] || [ "$install_response" = "Y" ]; then
            printf "Detecting remote operating system... "
            local os_type
            os_type=$(ssh "${remote_user}@${remote_host}" "if [ -f /etc/debian_version ]; then echo 'debian'; elif [ -f /etc/redhat-release ]; then echo 'redhat'; elif [ -f /etc/arch-release ]; then echo 'arch'; else echo 'unknown'; fi")
            printf "%s\n" "$os_type"

            local install_cmd=""
            case "$os_type" in
                "debian") install_cmd="sudo apt-get update && sudo apt-get install -y hcxtools hashcat";;
                "redhat") install_cmd="sudo yum install -y epel-release && sudo yum install -y hcxtools hashcat";;
                "arch") install_cmd="sudo pacman -Syu --noconfirm hcxtools hashcat";;
                *) printf "%b\n" "${RED}Unsupported OS for automatic installation. Please install manually.${NC}";;
            esac

            if [ -n "$install_cmd" ]; then
                printf "Running installation command on remote host:\n${YELLOW}%s${NC}\n" "$install_cmd"
                ssh -t "${remote_user}@${remote_host}" "$install_cmd"
                # Re-check after installation
                printf "\nRe-checking for hcxtools... "
                if ssh "${remote_user}@${remote_host}" 'command -v hcxpcapngtool' >/dev/null 2>&1; then printf "%b\n" "${GREEN}Found${NC}"; else printf "%b\n" "${RED}Failed${NC}"; fi
                printf "Re-checking for hashcat... "
                if ssh "${remote_user}@${remote_host}" 'command -v hashcat' >/dev/null 2>&1; then printf "%b\n" "${GREEN}Found${NC}"; else printf "%b\n" "${RED}Failed${NC}"; fi
            fi
        fi
    fi

    # --- Step 5: Update Configuration File ---
    printf "\n%b\n" "${BLUE}--- Step 4: Save Configuration ---${NC}"
    printf "The remote server setup seems complete.\n"
    printf "Shall I save these settings to '${YELLOW}/etc/hcxtools/hcxscript.conf${NC}'? [y/N] "
    read -r save_response
    if [ "$save_response" = "y" ] || [ "$save_response" = "Y" ]; then
        local CONFIG_FILE="/etc/hcxtools/hcxscript.conf"
        if [ ! -f "$CONFIG_FILE" ]; then touch "$CONFIG_FILE"; fi
        local TEMP_CONF="/tmp/hcxconf.tmp.$$"
        
        # Atomically update the config file by rebuilding it
        grep -vE '^(# *)?REMOTE_ANALYSIS_ENABLED=|^(# *)?REMOTE_HOST=|^(# *)?REMOTE_USER=' "$CONFIG_FILE" > "$TEMP_CONF"
        
        printf "\n# Settings updated by --utility setup-remote on %s\n" "$(date)" >> "$TEMP_CONF"
        printf "REMOTE_ANALYSIS_ENABLED=1\n" >> "$TEMP_CONF"
        printf "REMOTE_HOST=\"%s\"\n" "$remote_host" >> "$TEMP_CONF"
        printf "REMOTE_USER=\"%s\"\n" "$remote_user" >> "$TEMP_CONF"
        
        # Check if we can write to the file, use sudo if necessary
        if mv "$TEMP_CONF" "$CONFIG_FILE" 2>/dev/null; then
            printf "%b\n" "${GREEN}Configuration saved successfully!${NC}"
        elif sudo -n true 2>/dev/null; then # Check for non-interactive sudo
            printf "Attempting to save configuration with sudo...\n"
            if sudo mv "$TEMP_CONF" "$CONFIG_FILE"; then
                 printf "%b\n" "${GREEN}Configuration saved successfully!${NC}"
            else
                 printf "%b\n" "${RED}Failed to save configuration even with sudo.${NC}"
                 rm -f "$TEMP_CONF"
            fi
        else
            printf "%b\n" "${RED}Failed to save configuration. Please run this command to complete the process:${NC}"
            printf "sudo mv %s %s\n" "$TEMP_CONF" "$CONFIG_FILE"
        fi
    fi

    printf "\n%b\n" "${GREEN}--- ✅ Remote Setup Complete ---${NC}"
    printf "Remote host ${YELLOW}%s@%s${NC} is ready for analysis.\n" "$remote_user" "$remote_host"
}

run_trends() {
    printf "\n%b\n" "${BLUE}--- 📈 Historical Trend Analysis ---${NC}"

    # --- Step 1: Check Dependencies ---
    if [ ! -f "$DB_FILE" ] || [ ! -s "$DB_FILE" ]; then
        printf "%b\n" "${RED}Error: Database file not found or is empty at '${DB_FILE}'.${NC}"
        printf "Please run '--mode db' first to populate the database with historical data.\n"
        return 1
    fi
    if ! command -v sqlite3 >/dev/null 2>&1; then
        printf "%b\n" "${RED}Error: 'sqlite3' is required for this utility but is not installed.${NC}"
        return 1
    fi

    local query_result
    local count=0

    # --- Section 1: New Discoveries (Last 7 Days) ---
    printf "\n%b\n" "${CYAN}--- Newly Discovered Devices (Last 7 Days) ---${NC}"
    printf "%b\n" "${YELLOW}Networks:${NC}"
    query_result=$(sqlite3 -separator '|' "$DB_FILE" "SELECT bssid, essid_b64, vendor FROM networks WHERE first_seen >= date('now', '-7 days');")
    if [ -z "$query_result" ]; then
        printf "  -> None found.\n"
    else
        echo "$query_result" | while IFS="|" read -r bssid essid_b64 vendor; do
            local essid_plain
            essid_plain=$(echo "$essid_b64" | base64 -d 2>/dev/null)
            printf "  - %-18s %-25s (%s)\n" "$bssid" "$essid_plain" "$vendor"
        done
    fi

    printf "%b\n" "${YELLOW}Clients:${NC}"
    query_result=$(sqlite3 -separator '|' "$DB_FILE" "SELECT mac, vendor FROM clients WHERE first_seen >= date('now', '-7 days');")
    if [ -z "$query_result" ]; then
        printf "  -> None found.\n"
    else
        echo "$query_result" | while IFS="|" read -r mac vendor; do
            printf "  - %-18s (%s)\n" "$mac" "$vendor"
        done
    fi

    # --- Section 2: Stale Devices (Not Seen in 30+ Days) ---
    printf "\n%b\n" "${CYAN}--- Stale Devices (Not Seen in 30+ Days) ---${NC}"
    printf "%b\n" "${YELLOW}Networks:${NC}"
    query_result=$(sqlite3 -separator '|' "$DB_FILE" "SELECT bssid, essid_b64, last_seen FROM networks WHERE last_seen <= date('now', '-30 days');")
     if [ -z "$query_result" ]; then
        printf "  -> None found.\n"
    else
        echo "$query_result" | while IFS="|" read -r bssid essid_b64 last_seen; do
            local essid_plain
            essid_plain=$(echo "$essid_b64" | base64 -d 2>/dev/null)
            printf "  - %-18s %-25s (Last seen: %s)\n" "$bssid" "$essid_plain" "$last_seen"
        done
    fi

    # --- Section 3: Recent Cracking Activity (Last 24 Hours) ---
    printf "\n%b\n" "${CYAN}--- Recently Cracked Passwords (Last 24 Hours) ---${NC}"
    query_result=$(sqlite3 -separator '|' "$DB_FILE" "SELECT essid_b64, psk, cracked_timestamp FROM hashes WHERE cracked_timestamp >= datetime('now', '-1 day');")
    if [ -z "$query_result" ]; then
        printf "  -> No passwords cracked in the last 24 hours.\n"
    else
        echo "$query_result" | while IFS="|" read -r essid_b64 psk cracked_timestamp; do
            local essid_plain
            essid_plain=$(echo "$essid_b64" | base64 -d 2>/dev/null)
            printf "  - %b%-25s${NC} -> PSK: %b%s${NC} (Cracked: %s)\n" "${GREEN}" "$essid_plain" "${YELLOW}" "$psk" "$cracked_timestamp"
        done
    fi
}

version_ge() { [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" != "$1" ]; }

run_recommend() {
    shift
    local files_to_process="$@"
    if [ -z "$files_to_process" ]; then files_to_process=$(find "$CAPTURE_DIR" -name "*.pcapng" 2>/dev/null); fi
    if [ -z "$files_to_process" ]; then printf "%b\n" "${RED}No .pcapng files found to process.${NC}"; return 1; fi

    printf "%b\n" "${CYAN}--- 🧠 Running Strategic Recommendation Engine ---${NC}"

    # --- Step 1: Data Gathering ---
    local TEMP_DIR="/tmp/recommend_data_$$"
    mkdir -p "$TEMP_DIR"
    local ALL_HASHES_FILE="$TEMP_DIR/all_hashes.hc22000"
    local ID_FILE="$TEMP_DIR/identities.txt"
    local USER_FILE="$TEMP_DIR/usernames.txt"
    local NMEA_FILE="$TEMP_DIR/track.nmea"
    local ESSID_FILE="$TEMP_DIR/essids.txt"

    run_with_spinner "Performing initial data extraction..." "hcxpcapngtool" $files_to_process -o "$ALL_HASHES_FILE" -I "$ID_FILE" -U "$USER_FILE" --nmea="$NMEA_FILE" -E "$ESSID_FILE"
    
    # --- Step 2: Analysis ---
    local TOTAL_HASHES=0; if [ -f "$ALL_HASHES_FILE" ]; then TOTAL_HASHES=$(wc -l < "$ALL_HASHES_FILE"); fi
    local PMKID_COUNT=0; local EAPOL_COUNT=0
    if [ "$TOTAL_HASHES" -gt 0 ]; then
        PMKID_COUNT=$(hcxhashtool -i "$ALL_HASHES_FILE" --type=1 2>/dev/null | wc -l)
        EAPOL_COUNT=$(hcxhashtool -i "$ALL_HASHES_FILE" --type=2 2>/dev/null | wc -l)
    fi
    local PII_COUNT=0; if [ -f "$ID_FILE" ]; then PII_COUNT=$((PII_COUNT + $(wc -l < "$ID_FILE"))); fi
    if [ -f "$USER_FILE" ]; then PII_COUNT=$((PII_COUNT + $(wc -l < "$USER_FILE"))); fi
    local HAS_GPS_DATA=0; if [ -s "$NMEA_FILE" ]; then HAS_GPS_DATA=1; fi
    local ESSID_COUNT=0; if [ -f "$ESSID_FILE" ]; then ESSID_COUNT=$(wc -l < "$ESSID_FILE"); fi

    # --- Step 3: Recommendation Logic ---
    local recommendations=""
    add_recommendation() {
        local priority="$1"
        local title="$2"
        local detail="$3"
        # Use a special separator (e.g., |) to store structured recommendations
        recommendations="${recommendations}${priority}|${title}|${detail}\n"
    }

    if [ "$TOTAL_HASHES" -eq 0 ]; then
        add_recommendation "High" "Poor Capture Results" "No crackable hashes were found. To improve results, try running 'hcxdumptool-launcher --hunt-handshakes' to actively deauthenticate clients and force handshakes."
    else
        # PMKID vs EAPOL analysis
        if [ "$PMKID_COUNT" -gt $((EAPOL_COUNT * 2)) ]; then
            add_recommendation "High" "PMKID Dominance Detected" "The capture contains significantly more PMKIDs than client handshakes. This is excellent for passive attacks. Focus on cracking these first. Use '--type 1' in hash filtering."
        elif [ "$EAPOL_COUNT" -gt $((PMKID_COUNT * 2)) ]; then
            add_recommendation "Medium" "Client Handshake Dominance" "You have a high number of client-based handshakes. This is a strong position for cracking. Consider running '--mode vuln' to check for common passwords."
        fi

        # PII analysis
        if [ "$PII_COUNT" -gt 0 ]; then
            add_recommendation "Critical" "Enterprise Credentials Found" "WPA-Enterprise identities or usernames were discovered. This is a significant finding. Use '--mode pii' to view the credentials and consider them for targeted password attacks."
        fi

        # ESSID analysis
        if [ "$ESSID_COUNT" -gt 10 ]; then
            add_recommendation "Medium" "High Network Density" "A large number of unique network names (ESSIDs) were found. People often reuse parts of network names in passwords. Use '--utility generate_wordlist' to create a custom, targeted wordlist from them."
        fi
    fi

    # GPS analysis
    if [ "$HAS_GPS_DATA" -eq 1 ]; then
        add_recommendation "Low" "GPS Data Available" "Your captures contain GPS tracks. Visualize your wardriving session by running '--utility generate-dashboard' to see the data on a map."
    fi

    # --- Step 4: Formatted Output ---
    printf "\n%b\n" "${CYAN}--- 🔍 Strategic Recommendations ---${NC}"
    printf "Based on the analysis of your capture data, here are some suggested next steps:\n"

    if [ -z "$recommendations" ]; then
        printf "\n%b\n" "${GREEN}▶ No specific high-priority vectors were identified from this analysis. Your capture contains a standard mix of data. Consider running a general '--mode vuln' scan to check for weak default passwords.${NC}"
    else
        # Sort recommendations by priority and print
        printf "%b" "$recommendations" | sort -t'|' -k1 | while IFS="|" read -r priority title detail; do
            local color="${GREEN}"
            if [ "$priority" = "High" ]; then color="${YELLOW}"; fi
            if [ "$priority" = "Critical" ]; then color="${RED}"; fi
            
            printf "\n%b[%s] %s${NC}\n" "$color" "$priority" "$title"
            printf "   %s\n" "$detail"
        done
    fi

    # Cleanup
    rm -rf "$TEMP_DIR"
}

run_find_reuse_targets() {
    printf "\n%b\n" "${CYAN}--- 🔎 Finding Potential Credential Reuse Targets ---${NC}"

    # --- Step 1: Check Dependencies ---
    if [ ! -f "$DB_FILE" ] || [ ! -s "$DB_FILE" ]; then
        printf "%b\n" "${RED}Error: Database file not found or is empty at '${DB_FILE}'.${NC}"
        printf "Please run '--mode db' first to populate the database.\n"
        return 1
    fi
    if ! command -v sqlite3 >/dev/null 2>&1; then
        printf "%b\n" "${RED}Error: 'sqlite3' is required for this utility but is not installed.${NC}"
        return 1
    fi

    local TEMP_DIR="/tmp/reuse_targets_$$"
    mkdir -p "$TEMP_DIR"
    # Set a trap to ensure temporary files are cleaned up on exit
    trap 'rm -rf "$TEMP_DIR"; trap - INT TERM EXIT' INT TERM EXIT

    # --- Step 2: Extract and Sort Data using Temp Files ---
    printf "Analyzing database...\n"
    
    # Get all cracked passwords and save to a sorted temp file
    local cracked_query="SELECT essid_b64, psk FROM hashes WHERE psk IS NOT NULL AND psk != '';"
    sqlite3 -separator '|' "$DB_FILE" "$cracked_query" | sort -u -t'|' -k1,1 > "$TEMP_DIR/cracked.sorted"

    if [ ! -s "$TEMP_DIR/cracked.sorted" ]; then
        printf "%b\n" "${YELLOW}No cracked passwords found in the database to check against.${NC}"
        return 0
    fi

    # Get all uncracked networks and save to a sorted temp file
    local uncracked_query="SELECT bssid, essid_b64 FROM hashes WHERE psk IS NULL OR psk = '';"
    sqlite3 -separator '|' "$DB_FILE" "$uncracked_query" | sort -u -t'|' -k2,2 > "$TEMP_DIR/uncracked.sorted"

    # --- Step 3: Join the data and Generate the Report ---
    printf "\n%b\n" "${BLUE}--- Credential Reuse Report ---${NC}"

    # 'join' is a POSIX utility that finds matching lines in two sorted files.
    # Here, it joins on the base64 ESSID field.
    # The output format will be: essid_b64|psk|bssid
    join -t'|' -1 1 -2 2 "$TEMP_DIR/cracked.sorted" "$TEMP_DIR/uncracked.sorted" | \
    # Pipe the results into awk for professional formatting
    awk -F'|' '
        # This function decodes base64, which is safer inside awk
        function b64dec(s,   cmd, line) {
            cmd = "echo " s " | base64 -d 2>/dev/null";
            cmd | getline line;
            close(cmd);
            return line;
        }

        # For each line from join, store the target BSSID under the ESSID
        {
            essid = $1;
            psk[essid] = $2;
            targets[essid] = targets[essid] "        - " $3 "\n";
        }

        END {
            if (length(psk) == 0) {
                 printf "\n%b\n", "\033[0;32mNo instances of potential credential reuse were found.\033[0m";
            } else {
                for (essid in psk) {
                    essid_plain = b64dec(essid);
                    printf "\n\033[0;32m[+] ESSID:\033[0m %s\n", essid_plain;
                    printf "    \033[1;33mKnown PSK:\033[0m  %s\n", psk[essid];
                    printf "    \033[0;36mPotential Reuse Targets (BSSIDs):\033[0m\n";
                    printf "%s", targets[essid];
                }
            }
        }
    '
}

run_interactive_mode() {
    local prompt_prefix=""; [ "$1" = "remote" ] && prompt_prefix="${RED}[REMOTE]${NC} "
    printf "%b\n" "${CYAN}--- HCX Analyzer Interactive Mode ${prompt_prefix}---${NC}"; echo "Please select a mode:"; echo ""
    printf "%b\n" "${YELLOW}--- ANALYSIS MODES ---${NC}"; echo "  1) summary"; echo "  2) intel"; echo "  3) vuln"; echo "  4) pii"; echo "  5) db"
    printf "%b\n" "${YELLOW}--- UTILITY MODES ---${NC}"; echo "  6) filter_hashes"; echo "  7) generate_wordlist"; echo "  8) merge_hashes"
    echo "  9) export"; echo "  10) geotrack"; echo "  11) remote_crack"; echo "  12) health_check"
    printf "Choice [1-12]: "; read -r choice
    case "$choice" in ''|*[!0-9]*) printf "\n%b\n" "${RED}Error: Invalid input.${NC}"; exit 1;; esac
    MODE=""; UTILITY_ACTION=""
    case "$choice" in
        1) MODE="summary";; 2) MODE="intel";; 3) MODE="vuln";; 4) MODE="pii";; 5) MODE="db";;
        6) UTILITY_ACTION="filter_hashes";; 7) UTILITY_ACTION="generate_wordlist";;
        8) UTILITY_ACTION="merge_hashes";; 9) UTILITY_ACTION="export";;
        10) UTILITY_ACTION="geotrack";; 11) UTILITY_ACTION="remote_crack";;
        12) UTILITY_ACTION="health_check";;
        *) printf "\n%b\n" "${RED}Error: Invalid choice.${NC}"; exit 1;;
    esac
    local action_to_run=""; if [ -n "$MODE" ]; then action_to_run=$MODE; else action_to_run=$UTILITY_ACTION; fi
    if [ "$action_to_run" = "health_check" ]; then run_health_check; exit 0; fi
    local files_to_process=""
    if [ "$action_to_run" = "merge_hashes" ]; then files_to_process=$(find "$CAPTURE_DIR" -name '*.hc22000');
    elif [ "$action_to_run" = "geotrack" ]; then files_to_process=$(find "$CAPTURE_DIR" -name '*.nmea');
    else files_to_process=$(find "$CAPTURE_DIR" -name '*.pcapng'); fi
    if [ -z "$files_to_process" ]; then printf "%b\n" "${YELLOW}No relevant files found in '$CAPTURE_DIR'.${NC}"; exit 0; fi
    set -- $files_to_process; "run_${action_to_run}" "interactive" "$@"
}

main() {
    if [ $# -eq 0 ]; then run_interactive_mode; exit 0; fi
    local TARGET_ARGS=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --mode) MODE="$2"; shift 2 ;;
            --remote-mode) REMOTE_ACTION=1; MODE="$2"; shift 2;;
            --utility) UTILITY_ACTION="$2"; shift 2 ;;
            --remote-utility) REMOTE_ACTION=1; UTILITY_ACTION="$2"; shift 2;;
            --summary-mode) SUMMARY_MODE="$2"; shift 2;;
            --remote-host) REMOTE_SERVER_HOST="$2"; shift 2;;
            --tag) SESSION_TAG="$2"; shift 2;;
            --mac-list) MAC_LIST="$2"; shift 2;;
            --mac-skiplist) MAC_SKIPLIST="$2"; shift 2;;
            --essid) ESSID_FILTER="$2"; shift 2;;
            --essid-regex) ESSID_REGEX="$2"; shift 2;;
            --monitor) MONITOR_CRACK=1; shift;;
            --vendor) VENDOR_FILTER="$2"; shift 2;;
            --essid-min) ESSID_MIN_LEN="$2"; shift 2;;
            --essid-max) ESSID_MAX_LEN="$2"; shift 2;;
            --type) HASH_TYPE="$2"; shift 2;;
            --authorized) AUTHORIZED_ONLY=1; shift;;
            --challenge) CHALLENGE_ONLY=1; shift;;
            -v|--verbose) VERBOSE=1; shift ;;
            -h|--help) show_usage; exit 0 ;;
            *) if [ -z "$TARGET_ARGS" ]; then TARGET_ARGS="$1"; else TARGET_ARGS="$TARGET_ARGS $1"; fi; shift ;;
        esac
    done
    if [ -z "$MODE" ] && [ -z "$UTILITY_ACTION" ]; then MODE="summary"; fi
    if [ "$MODE" = "interactive" ]; then
        if [ "$REMOTE_ACTION" -eq 1 ]; then run_remote_execution "mode" "interactive"; else run_interactive_mode "local"; fi
        exit 0
    fi
    local action_to_run=""; local action_type="mode"
    if [ -n "$MODE" ]; then action_to_run=$MODE; action_type="mode"; elif [ -n "$UTILITY_ACTION" ]; then action_to_run=$UTILITY_ACTION; action_type="utility"; fi
    if [ -z "$action_to_run" ]; then printf "%b\n" "${RED}No valid action specified.${NC}"; exit 1; fi
    if [ "$action_to_run" = "health_check" ]; then run_health_check; exit 0; fi
    
    # --- New File Discovery Logic with Tag Filtering ---
    local files_to_process=""
    local target_paths="$TARGET_ARGS"
    if [ -z "$target_paths" ]; then target_paths="$CAPTURE_DIR"; fi

    # Determine the file pattern based on the action and tag
    local find_name_pattern=""
    if [ "$action_to_run" = "merge_hashes" ]; then
        find_name_pattern="*.hc22000"
    elif [ "$action_to_run" = "geotrack" ]; then
        find_name_pattern="*.nmea"
    else
        if [ -n "$SESSION_TAG" ]; then
            local sanitized_tag
            sanitized_tag=$(echo "$SESSION_TAG" | tr -cd '[:alnum:]_-')
            find_name_pattern="*${sanitized_tag}*.pcapng"
        else
            find_name_pattern="*.pcapng"
        fi
    fi
    
    for path in $target_paths; do
        if [ -d "$path" ]; then
            # Use find to get files matching the pattern
            local found_files
            found_files=$(find "$path" -name "$find_name_pattern")
            if [ -n "$found_files" ]; then
                files_to_process="$files_to_process $found_files"
            fi
        elif [ -f "$path" ]; then
            # If a specific file is provided, add it regardless of tag
            files_to_process="$files_to_process $path"
        fi
    done

    if [ -z "$files_to_process" ] && [ "$action_to_run" != "interactive" ]; then
        if [ -n "$SESSION_TAG" ]; then
             printf "%b\n" "${YELLOW}No relevant files found for tag: '$SESSION_TAG'${NC}"
        else
             printf "%b\n" "${YELLOW}No relevant files found.${NC}"
        fi
        exit 0
    fi
    
    set -- $files_to_process
    if [ "$REMOTE_ACTION" -eq 1 ]; then
        run_remote_execution "$action_type" "$action_to_run" "$@"
    else
        "run_${action_to_run}" "local" "$@"
    fi
    printf "\n%b\n" "${GREEN}Analyzer finished.${NC}"
}

main "$@"
