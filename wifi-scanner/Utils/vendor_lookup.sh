#!/bin/bash

# Color & style constants
RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

# Require root privileges
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[!]${NC} This script must be run as root." >&2
    exit 1
fi

# Go back to main menus
go_back() {
    echo -e "${GREEN}[✓]${NC} Returning to main menu..."
    sleep 0.3
    exec ./start.sh
}

# Display Banner
display_welcome() {
    clear
    echo
    echo -e "${GREEN}==============================================${NC}"
    echo -e "${BOLD}${GREEN}               Vendor Lookup                ${NC}${BOLD}${NC}"
    echo -e "${GREEN}==============================================${NC}"
    echo
    sleep 0.3
}

# Valide mac address in format XX-XX-XX
validate_mac() {
    [[ $1 =~ ^([A-Fa-f0-9]{2})-([A-Fa-f0-9]{2})-([A-Fa-f0-9]{2})$ ]]
}

# Check for vendor
lookup() {
    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Enter MAC prefix (XX-XX-XX) or 0 to go back: ")" mac_prefix
        if [[ "$mac_prefix" == "0" ]]; then
            go_back
        elif validate_mac "$mac_prefix"; then
            break
        else
            echo -e "${RED}[!]${NC} Invalid format; use XX-XX-XX."
            sleep 0.3
        fi
    done

    local match
    match=$(grep -i "^$mac_prefix" /var/lib/ieee-data/oui.txt)
    if [[ -z $match ]]; then
        echo -e "${RED}[!]${NC} No vendor found for prefix ${mac_prefix}."
    else
        local company
        company=$(echo "$match" | sed 's/.*(hex)[[:space:]]*//')
        echo -e "${GREEN}[✓]${NC} Vendor: ${company}"
    fi
}


# Main entry point
main() {
    display_welcome
    while true; do
        lookup
    done
}

main
