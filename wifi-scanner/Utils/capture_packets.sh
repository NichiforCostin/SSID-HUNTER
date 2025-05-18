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

# Go back to main menu
go_back() {
    echo -e "${GREEN}[✓]${NC} Returning to main menu..."
    sleep 0.5
    exec ./start.sh
}

# Shows options and selects type of scan (band or channel) or shows captured files in Captures/.
prompt_to_continue() {
    local options=("View saved capture files" "Scan entire band" "Scan specific channel")

    clear
    echo
    echo -e "${GREEN}==============================================${NC}"
    echo -e "${BOLD}${GREEN}         Capture Mode Scan Options         ${NC}${BOLD}${NC}"
    echo -e "${GREEN}==============================================${NC}"
    echo
    echo -e "${RED}[!]${NC} Make sure you have monitor mode turned on."
    sleep 0.5
    echo

    for i in "${!options[@]}"; do
        echo -e "  ${GREEN}[$((i+1))]${NC} ${options[$i]}"
        sleep 0.1
    done
    echo -e "  ${GREEN}[0]${NC} Go back"
    echo
    sleep 0.5

    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Select an option: ")" option
        case $option in
            1) list_captures; break ;;
            2) scan_mode="band"; break ;;
            3) scan_mode="channel"; break ;;
            0) go_back ;;
            *) echo -e "${RED}[!]${NC} Invalid option. Please select 0-3."; sleep 0.3 ;;
        esac
    done

    select_interface

    if [[ "$scan_mode" == "band" ]]; then
        select_band
    else
        select_channel
    fi

    ask_save_to_file
}

# Show captures in Captures/ directory.
list_captures() {
    # Activează nullglob ca să dispară pattern-urile fără fișiere
    shopt -s nullglob

    # Colectează fișierele relevante
    local files=(
        Captures/*.cap
        Captures/*.gps
        Captures/*.csv
        Captures/*.kismet.netxml
        Captures/*.kismet.csv
    )

    # Dezactivează nullglob pentru a nu afecta alte părți
    shopt -u nullglob

    # Dacă nu există fișiere, anunță și revine
    if [ ${#files[@]} -eq 0 ]; then
        echo -e "${RED}[!]${NC} No capture files found in Captures/."
        sleep 0.5
        prompt_to_continue
    fi

    # Afișează lista cu opțiunea de back
    echo -e "${GREEN}[*]${NC} Available capture files:"
    echo
    for i in "${!files[@]}"; do
        echo -e "    ${GREEN}[$((i+1))]${NC} ${files[$i]##*/}"
        sleep 0.1
    done
    echo -e "    ${GREEN}[0]${NC} Back"
    echo

    # Primește și procesează selecția
    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Select a file to open: ")" sel
        if [[ "$sel" == "0" ]]; then
            prompt_to_continue
        elif [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= ${#files[@]} )); then
            local file="${files[$((sel-1))]}"
            echo -e "${GREEN}[✓]${NC} Opening ${file##*/}..."
            case "$file" in
                *.cap|*.log.cap)
                    wireshark "$file" >/dev/null 2>&1 &
                    ;;
                *.gps)
                    xdg-open "$file" >/dev/null 2>&1 &
                    ;;
                *.csv|*.kismet.csv|*.kismet.netxml)
                    xdg-open "$file" >/dev/null 2>&1 &
                    ;;
            esac
            sleep 0.5
        else
            echo -e "${RED}[!]${NC} Invalid selection. Please choose 0-${#files[@]}."
            sleep 0.3
        fi
    done
}

# Select an interface that has monitor mode turned on 
select_interface() {
    echo -e "${GREEN}[*]${NC} Checking for interfaces in monitor mode..."
    sleep 0.8

    MONITOR_INTERFACES=()
    for iface in $(iw dev 2>/dev/null | awk '$1=="Interface"{i=$2} $1=="type"&&$2=="monitor"{print i}'); do
        MONITOR_INTERFACES+=("$iface")
    done

    if [ ${#MONITOR_INTERFACES[@]} -eq 0 ]; then
        echo -e "${RED}[!]${NC} No monitor interfaces found. Returning to main menu..."
        sleep 0.8
        prompt_to_continue
    fi

    echo -e "${GREEN}[✓]${NC} Monitor‐mode interfaces found:"
    echo
    for i in "${!MONITOR_INTERFACES[@]}"; do
        echo -e "  ${GREEN}[$((i+1))]${NC} ${MONITOR_INTERFACES[$i]}"
        sleep 0.1
    done
    echo -e "  ${GREEN}[0]${NC} Go back"
    echo

    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Select interface to capture packets: ")" sel
        if [[ $sel == "0" ]]; then
            prompt_to_continue
        elif [[ $sel =~ ^[0-9]+$ ]] && [ $sel -ge 1 ] && [ $sel -le ${#MONITOR_INTERFACES[@]} ]; then
            INTERFACE=${MONITOR_INTERFACES[$((sel-1))]}
            echo -e "${GREEN}[✓]${NC} Selected interface: $INTERFACE"
            sleep 0.8
            break
        else
            echo -e "${RED}[!]${NC} Invalid selection. Please choose 0-${#MONITOR_INTERFACES[@]}."
            sleep 0.3
        fi
    done
}

# Select band (2.4GHz or 5GHz)
select_band() {
    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Band (a = 2.4GHz, g = 5GHz): ")" band
        if [[ "$band" =~ ^(a|g)$ ]]; then
            scan_flag="--band $band"
            echo -e "${GREEN}[✓]${NC} Band set: $band"
            sleep 0.3
            break
        else
            echo -e "${RED}[!]${NC} Invalid. Enter 'a' or 'g'."
            sleep 0.3
        fi
    done
}

# Select a channel (1-14)
select_channel() {
    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Channel (1-14): ")" channel
        if [[ "$channel" =~ ^[0-9]+$ ]] && [ $channel -ge 1 ] && [ $channel -le 14 ]; then
            scan_flag="-c $channel"
            echo -e "${GREEN}[✓]${NC} Channel set: $channel"
            sleep 0.3
            break
        else
            echo -e "${RED}[!]${NC} Invalid. Enter a number between 1 and 14."
            sleep 0.3
        fi
    done
}

# Ask the user if they want to save the caputured traffic and if yes show options for output format
ask_save_to_file() {
    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Save to file? (yes/no): ")" save_option
        if [[ "$save_option" == "yes" ]]; then
            echo -e "${GREEN}[*]${NC} Choose output format:"
            echo
            idx=0
            for f in csv cap gps kismet.netxml kismet.csv all; do
                ((idx++))
                echo -e "  ${GREEN}[${idx}]${NC} ${f}"
                sleep 0.1
            done
            echo
            while true; do
                read -rp "$(echo -e "${GREEN}[?]${NC} Select format: ")" fmt
                if [[ $fmt -ge 1 && $fmt -le 6 ]]; then
                    read -rp "$(echo -e "${GREEN}[?]${NC} File name ${RED}(no ext)${NC}: ")" file_name
                    mkdir -p Captures
                    case $fmt in
                        1) output_format="-w Captures/$file_name --output-format csv" ;;
                        2) output_format="-w Captures/$file_name --output-format cap" ;;
                        3) output_format="-w Captures/$file_name --output-format gps" ;;
                        4) output_format="-w Captures/$file_name --output-format kismet.netxml" ;;
                        5) output_format="-w Captures/$file_name --output-format kismet.csv" ;;
                        6) output_format="-w Captures/$file_name" ;;
                    esac
                    echo -e "${GREEN}[✓]${NC} Output format set."
                    sleep 0.3
                    break
                else
                    echo -e "${RED}[!]${NC} Invalid. Select 1-6."
                    sleep 0.3
                fi
            done
            break
        elif [[ "$save_option" == "no" ]]; then
            output_format=""
            break
        else
            echo -e "${RED}[!]${NC} Invalid. Type 'yes' or 'no'."
            sleep 0.3
        fi
    done
    sleep 0.3
    start_packet_capture
}


# Run airodump-ng 
start_packet_capture() {
    clear
    echo -e "${GREEN}[✓]${NC} To stop capturing, press Ctrl+C."
    sleep 0.8

    cmd="airodump-ng $scan_flag $INTERFACE"
    [[ -n "${output_format-}" ]] && cmd+=" $output_format"

    echo -e "${GREEN}[*]${NC} Starting packet capture..."
    eval "$cmd"

    after_capture_options
}

# Show options after process is completed 
after_capture_options() {
    echo -e "${GREEN}[*]${NC} Choose next operation:"
    echo
    echo -e "  ${GREEN}[1]${NC} New capture"
    echo -e "  ${GREEN}[0]${NC} Main menu"
    echo
    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Select an option: ")" opt
        case $opt in
            1) clear; prompt_to_continue; return ;;
            0) go_back; return ;;
            *) echo -e "${RED}[!]${NC} Type 0 or 1."; sleep 0.3 ;;
        esac
    done
}

# Main entry
main() {
    clear
    prompt_to_continue
}

main
