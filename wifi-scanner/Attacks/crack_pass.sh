#!/bin/bash

source Attacks/common.sh
    
# Color & style constants
RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

# Require root privileges
require_root

# Display welcome banner
display_welcome() {
    clear
    echo
    echo -e "${GREEN}==============================================${NC}"
    echo -e "${BOLD}${GREEN}              Password recovery            ${NC}${BOLD}${NC}"
    echo -e "${GREEN}==============================================${NC}"
    echo
    sleep 0.3
}

# Check for .cap or .iv files
check_captures() {
    shopt -s nullglob
    captures=(Captures/*.cap Captures/*.iv Captures/*.22000 Captures/*.creds)
    shopt -u nullglob
    if [ ${#captures[@]} -eq 0 ]; then
        echo -e "${RED}[!]${NC} No .cap, .22000 or .iv files in Captures/. Returning to main menu..."
        sleep 0.5
        go_back
    fi
}

# Let the user choose a capture file
choose_capture() {
    echo -e "${GREEN}[*]${NC} Checking for capture files..."
    sleep 0.3
    echo -e "${GREEN}[*]${NC} Available capture files:"
    echo
    for i in "${!captures[@]}"; do
        echo -e "    ${GREEN}[$((i+1))]${NC} ${captures[$i]##*/}"
        sleep 0.1
    done
    echo -e "    ${GREEN}[0]${NC} Go back"
    echo
    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Select a file:") " sel
        if [[ "$sel" == "0" ]]; then
            go_back
        elif [[ "$sel" =~ ^[0-9]+$ ]] && (( sel>=1 && sel<=${#captures[@]} )); then
            selected_capture=${captures[$((sel-1))]}
            echo -e "${GREEN}[✓]${NC} Selected: ${selected_capture##*/}"
            sleep 0.3
            break
        else
            echo -e "${RED}[!]${NC} Invalid; choose 0-${#captures[@]}."
            sleep 0.3
        fi
    done
}

# Let the user choose a wordlist from /opt
choose_wordlist() {
    shopt -s nullglob
    lists=(/opt/passwords/*.txt)
    shopt -u nullglob
    if [ ${#lists[@]} -eq 0 ]; then
        echo -e "${RED}[!]${NC} No wordlists found in /opt/passwords/. Returning..."
        sleep 0.5
        go_back
    fi

    echo -e "${GREEN}[*]${NC} Available wordlists in /opt/passwords/:"
    echo
    for i in "${!lists[@]}"; do
        echo -e "    ${GREEN}[$((i+1))]${NC} ${lists[$i]##*/}"
        sleep 0.1
    done
    echo -e "    ${GREEN}[0]${NC} Go back"
    echo
    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Select a wordlist: ") " sel
        if [[ "$sel" == "0" ]]; then
            go_back
        elif [[ "$sel" =~ ^[0-9]+$ ]] && (( sel>=1 && sel<=${#lists[@]} )); then
            selected_wordlist=${lists[$((sel-1))]}
            echo -e "${GREEN}[✓]${NC} Using: ${selected_wordlist##*/}"
            sleep 0.3
            break
        else
            echo -e "${RED}[!]${NC} Invalid; choose 0-${#lists[@]}."
            sleep 0.3
        fi
    done
}

# Let the user choose cracking method, including new WEP option
choose_method() {
    echo -e "${GREEN}[*]${NC} Choose recovery method:"
    echo
    echo -e "    ${GREEN}[1]${NC} aircrack-ng (WPA/WPA2 dictionary attack)"
    echo -e "    ${GREEN}[2]${NC} aircrack-ng (WEP key from ARP replay)"
    echo -e "    ${GREEN}[3]${NC} cowpatty (WPS offline attack)"
    echo -e "    ${GREEN}[4]${NC} hashcat (MANA attack / Enterprise attack)"
    echo -e "    ${GREEN}[0]${NC} Go back"
    echo
    while true; do
        read -rp "$(echo -e "${GREEN}[*]${NC} Choose an option:") " opt
        case $opt in
            1) crack_aircrack; break ;;
            2) crack_wep;       break ;;
            3) crack_cowpatty;  break ;;
            4) crack_hash;      break ;;
            0) go_back ;;
            *) echo -e "${RED}[!]${NC} Type 0–3."; sleep 0.3 ;;
        esac
    done
}

# Run aircrack-ng WPA/WPA2
crack_aircrack() {
    echo -e "${GREEN}[*]${NC} Running aircrack-ng dictionary attack..."
    sleep 0.3
    choose_wordlist
    aircrack-ng -w "$selected_wordlist" "$selected_capture"
}

# Run cowpatty WPS attack
crack_cowpatty() {
    choose_wordlist
    read -rp "$(echo -e "${GREEN}[*]${NC} Enter target SSID: ") " ssid
    echo -e "${GREEN}[*]${NC} Running cowpatty..."
    sleep 0.3
    cowpatty -r "$selected_capture" -f "$selected_wordlist" -s "$ssid"
}

# Run aircrack-ng WEP key recovery from ARP replay
crack_wep() {
    echo -e "${GREEN}[*]${NC} Running WEP crack from ARP replay..."
    sleep 0.3

    aircrack-ng "$selected_capture"
}

# Run Hashcat 
crack_hash() {
    echo -e "${GREEN}[*]${NC} Running hashcat..."
    sleep 0.3
    choose_wordlist

    if [[ "$selected_capture" == *.creds ]]; then
        hash=$(sed -n 's/^\[EAP-MSCHAPV2 HASHCAT\][[:space:]]*//p' "$selected_capture")
        echo -e "${GREEN}[*]${NC} Detected .creds file, using MSCHAPv2 mode 5500"
        sleep 0.3
        sudo hashcat -m 5500 -a 0 "$hash" "$selected_wordlist" --force
    else
        echo -e "${GREEN}[*]${NC} Using EAPOL/WPA mode 22000"
        sleep 0.3
        sudo hashcat -m 22000 -a 0 "$selected_capture" "$selected_wordlist" --force
    fi
}

# After cracking, let the user retry or go back
after_crack() {
    echo -e "${GREEN}[*]${NC} Choose next operation:"
    echo
    echo -e "  ${GREEN}[1]${NC} Recover another password"
    echo -e "  ${GREEN}[0]${NC} Main menu"
    echo
    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Select an option: ")" opt
        case $opt in
            1) clear; main; break ;;
            0) go_back ;;
            *) echo -e "${RED}[!]${NC} Type 0 or 1."; sleep 0.3 ;;
        esac
    done
}

main() {
    display_welcome
    check_captures
    choose_capture
    choose_method
    after_crack
}

main
