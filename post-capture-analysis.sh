#!/bin/sh
# Post-Capture Analysis Script for hcxdumptool captures
# Automatically processes capture files with hcxtools
# Version: 1.0.0
# Compatible with WiFi Pineapple MK7

# Configuration
CAPTURE_DIR="/root/hcxdumps"
ANALYSIS_DIR="/root/hcx-analysis"
HASHCAT_DIR="$ANALYSIS_DIR/hashcat"
REPORTS_DIR="$ANALYSIS_DIR/reports"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Create directories
mkdir -p "$ANALYSIS_DIR" "$HASHCAT_DIR" "$REPORTS_DIR"

echo -e "${GREEN}=== HCX Post-Capture Analysis ===${NC}"
echo "Capture directory: $CAPTURE_DIR"
echo "Analysis directory: $ANALYSIS_DIR"
echo ""

# Find capture files from today (or specify pattern)
if [ -n "$1" ]; then
    PATTERN="$1"
else
    PATTERN="*$(date +%Y%m%d)*.pcapng"
fi

echo "Processing files matching: $PATTERN"
echo ""

# Process each capture file
for capture in $CAPTURE_DIR/$PATTERN; do
    if [ ! -f "$capture" ]; then
        echo -e "${YELLOW}No capture files found matching pattern${NC}"
        exit 1
    fi
    
    basename=$(basename "$capture" .pcapng)
    echo -e "${GREEN}Processing: $basename${NC}"
    
    # Generate report
    report="$REPORTS_DIR/${basename}-report.txt"
    echo "=== Capture Analysis Report ===" > "$report"
    echo "File: $capture" >> "$report"
    echo "Date: $(date)" >> "$report"
    echo "" >> "$report"
    
    # Get basic info
    echo "Getting capture info..."
    hcxpcapngtool --info=stdout "$capture" >> "$report" 2>&1
    
    # Extract hashes for hashcat
    echo "Extracting hashes..."
    hash_file="$HASHCAT_DIR/${basename}.hc22000"
    hcxpcapngtool -o "$hash_file" "$capture" > /tmp/hcx_tmp 2>&1
    
    # Count results
    if [ -f "$hash_file" ]; then
        hash_count=$(wc -l < "$hash_file")
        echo -e "${GREEN}  Extracted $hash_count hashes${NC}"
        echo "Hashes extracted: $hash_count" >> "$report"
    else
        echo -e "${RED}  No hashes extracted${NC}"
        echo "Hashes extracted: 0" >> "$report"
    fi
    
    # Extract ESSID list
    echo "Extracting ESSIDs..."
    essid_file="$ANALYSIS_DIR/${basename}-essids.txt"
    hcxpcapngtool -E "$essid_file" "$capture" 2>/dev/null
    
    if [ -f "$essid_file" ]; then
        essid_count=$(wc -l < "$essid_file")
        echo -e "${GREEN}  Found $essid_count unique ESSIDs${NC}"
        echo "Unique ESSIDs: $essid_count" >> "$report"
        echo "" >> "$report"
        echo "=== ESSID List ===" >> "$report"
        cat "$essid_file" >> "$report"
    fi
    
    # Extract identity list (usernames from EAP)
    echo "Extracting identities..."
    identity_file="$ANALYSIS_DIR/${basename}-identities.txt"
    hcxpcapngtool -I "$identity_file" "$capture" 2>/dev/null
    
    if [ -f "$identity_file" ] && [ -s "$identity_file" ]; then
        identity_count=$(wc -l < "$identity_file")
        echo -e "${GREEN}  Found $identity_count identities${NC}"
        echo "" >> "$report"
        echo "=== EAP Identities ===" >> "$report"
        cat "$identity_file" >> "$report"
    fi
    
    # Extract device list
    echo "Extracting device info..."
    device_file="$ANALYSIS_DIR/${basename}-devices.txt"
    hcxpcapngtool --info=stdout "$capture" 2>/dev/null | \
        grep -E "CLIENT|AP" | sort -u > "$device_file"
    
    # Create summary
    echo ""
    echo "=== Summary for $basename ===" | tee -a "$report"
    
    # Parse hcx output for statistics
    grep -E "PMKID|EAPOL|BEACON|PROBEREQUEST" /tmp/hcx_tmp | tee -a "$report"
    
    echo ""
    echo "Output files:"
    echo "  Report: $report"
    [ -f "$hash_file" ] && echo "  Hashes: $hash_file"
    [ -f "$essid_file" ] && echo "  ESSIDs: $essid_file"
    [ -f "$identity_file" ] && [ -s "$identity_file" ] && echo "  Identities: $identity_file"
    echo ""
done

# Cleanup
rm -f /tmp/hcx_tmp

# Generate combined files if multiple captures processed
file_count=$(ls -1 $CAPTURE_DIR/$PATTERN 2>/dev/null | wc -l)
if [ "$file_count" -gt 1 ]; then
    echo -e "${GREEN}=== Generating Combined Files ===${NC}"
    
    # Combine all hashes
    cat "$HASHCAT_DIR"/*.hc22000 2>/dev/null | sort -u > "$HASHCAT_DIR/all-hashes.hc22000"
    total_hashes=$(wc -l < "$HASHCAT_DIR/all-hashes.hc22000" 2>/dev/null || echo 0)
    echo "Total unique hashes: $total_hashes"
    
    # Combine all ESSIDs
    cat "$ANALYSIS_DIR"/*-essids.txt 2>/dev/null | sort -u > "$ANALYSIS_DIR/all-essids.txt"
    total_essids=$(wc -l < "$ANALYSIS_DIR/all-essids.txt" 2>/dev/null || echo 0)
    echo "Total unique ESSIDs: $total_essids"
fi

echo ""
echo -e "${GREEN}Analysis complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Review reports in: $REPORTS_DIR"
echo "2. Use hashcat with: hashcat -m 22000 $HASHCAT_DIR/*.hc22000 wordlist.txt"
echo "3. Target specific networks: hcxhashtool -i input.hc22000 --essid=TARGET"
echo ""