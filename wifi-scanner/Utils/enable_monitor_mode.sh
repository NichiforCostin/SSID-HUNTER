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

# Display welcome banner
# Show options (enable / disable) monitor mode to user
prompt_to_continue() {
    clear
    echo
    echo -e "${GREEN}==============================================${NC}"
    echo -e "${BOLD}${GREEN}               Monitor Mode Menu             ${NC}${BOLD}${NC}"
    echo -e "${GREEN}==============================================${NC}"
    echo
    echo -e "${RED}[!]${NC} Ensure you have at least one wireless interface available that supports monitor mode."
    sleep 0.5
    echo

    local options=("Enable monitor mode" "Disable monitor mode")

    for i in "${!options[@]}"; do
        echo -e "  ${GREEN}[$((i+1))]${NC} ${options[$i]}"
        sleep 0.1
    done
    echo -e "  ${GREEN}[0]${NC} Go back"
    echo

    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Select an option: ")" option
        case $option in
            1) check_wifi_card; break ;;
            2) check_monitor_interfaces; break ;;
            0) go_back ;;
            *) echo -e "${RED}[!]${NC} Invalid option. Please select 0-2."; sleep 0.3 ;;
        esac
    done
}

# Verify compatibily and extract available interfaces and list them to the user
check_wifi_card() {
    echo -e "${GREEN}[*]${NC} Checking wi-fi card compatibility..."
    sleep 0.8

    AIRMON_OUTPUT=$(airmon-ng)
    INTERFACES=($(echo "$AIRMON_OUTPUT" | grep -oP '^phy\d+\s+\K\w+'))

    if [ ${#INTERFACES[@]} -eq 0 ]; then
        echo -e "${RED}[!]${NC} No wi-fi card interfaces found, returning to main menu..."
        sleep 0.8
        go_back
    fi
    echo -e "${GREEN}[✓]${NC} Compatible interface found!"
    echo -e "${GREEN}[*]${NC} Available wi-fi card interfaces:"
    echo

    for i in "${!INTERFACES[@]}"; do
        echo -e "    ${GREEN}[$((i+1))]${NC} ${INTERFACES[$i]}"
        sleep 0.1
    done
    echo -e "    ${GREEN}[0]${NC} Go back"
    echo

    select_interface
}

# Selects interface to turn monitor mode on.
select_interface() {
    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Select an interface: ")" selection

        if [[ "$selection" == "0" ]]; then
            prompt_to_continue
        elif ! [[ "$selection" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}[!]${NC} Invalid input. Enter a number between 0 and ${#INTERFACES[@]}."
            sleep 0.3
        elif (( selection < 1 || selection > ${#INTERFACES[@]} )); then
            echo -e "${RED}[!]${NC} Invalid option. Please select 0-${#INTERFACES[@]}."
            sleep 0.3
        else
            INTERFACE=${INTERFACES[$((selection-1))]}
            # Verificăm dacă interfaţa e deja în monitor mode
            if iw dev "$INTERFACE" info 2>/dev/null | grep -q "type monitor"; then
                echo -e "${RED}[!]${NC} Interface '$INTERFACE' is already in monitor mode. Please choose a different interface or go back." 
                sleep 0.8
                continue
            fi
            echo -e "${GREEN}[✓]${NC} Selected interface: $INTERFACE"
            sleep 0.8
            break
        fi
    done

    check_bad_processes
}


# Verifys for "bad" processes and ask the user if they wish to stop them. No need to show them, usually unimportant. 
# This step is sometimes mandatory considering that some services may not work as expected.
check_bad_processes() {
    echo -e "${GREEN}[*]${NC} Checking for interfering processes..."
    sleep 0.8

    BAD_PROCESSES=$(airmon-ng check 2>/dev/null | grep -i "found")

    if [ -z "$BAD_PROCESSES" ]; then
        echo -e "${GREEN}[✓]${NC} No interfering processes found."
        sleep 0.3
    else
        echo "$BAD_PROCESSES"
        while true; do
            read -rp "$(echo -e "${GREEN}[?]${NC} Do you wish to kill these processes? ${RED}(Recommended!)${NC} (yes/no): ")" selection
            if [[ "$selection" == "yes" ]]; then
                airmon-ng check kill >/dev/null 2>&1
                echo -e "${GREEN}[✓]${NC} Processes killed."
                sleep 0.3
                break
            elif [[ "$selection" == "no" ]]; then
                sleep 0.3
                break
            else
                echo -e "${RED}[!]${NC} Invalid option. Please type 'yes' or 'no'."
                sleep 0.3
            fi
        done
    fi

    ask_monitor_mode
}

# Select a way to turn monitor mode on (airmon-ng or iw dev) 
ask_monitor_mode() {
    echo -e "${GREEN}[*]${NC} Choose how to enable monitor mode:"
    echo

    local options=("Use airmon-ng" "Use iw dev ${RED}(Recommended for attacking WPS!)${NC}")

    for i in "${!options[@]}"; do
        echo -e "  ${GREEN}[$((i+1))]${NC} ${options[$i]}"
        sleep 0.1
    done
    echo

    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Select an option: ")" option
        case $option in
            1) start_airmon_ng; break ;;
            2) start_iw_dev;  break ;;
            *) echo -e "${RED}[!]${NC} Invalid option. Please select 1 or 2."; sleep 0.3 ;;
        esac
    done
}

# Create monitor mode interface using iw dev
start_iw_dev() {
    echo -e "${GREEN}[*]${NC} Creating monitor interface based on $INTERFACE..."
    sleep 0.8

    iw dev "$INTERFACE" interface add mon0 type monitor >/dev/null 2>&1
    ifconfig mon0 up >/dev/null 2>&1
    echo -e "${GREEN}[✓]${NC} Monitor interface 'mon0' created."
    sleep 0.3

    after_monitor_options
}

# Activate monitor mode using airmon-ng 
start_airmon_ng() {
    echo -e "${GREEN}[*]${NC} Starting monitor mode on $INTERFACE..."
    sleep 0.8

    airmon-ng start "$INTERFACE" >/dev/null 2>&1
    echo -e "${GREEN}[✓]${NC} Monitor mode enabled on $INTERFACE."
    sleep 0.3

    after_monitor_options
}

# List interfaces in monitor mode
check_monitor_interfaces() {
    MONITOR_INTERFACES=()

    echo -e "${GREEN}[*]${NC} Checking for interfaces in monitor mode..."
    sleep 0.8

    AIRMON_IFACES=$(iw dev | grep 'Interface' | awk '{print $2}' | grep -E 'mon$')
    for iface in $AIRMON_IFACES; do
        MONITOR_INTERFACES+=("$iface:airmon-ng")
    done

    IW_IFACES=$(iw dev | grep 'Interface' | awk '{print $2}' | grep -E '^mon')
    for iface in $IW_IFACES; do
        MONITOR_INTERFACES+=("$iface:iw")
    done

    if [ ${#MONITOR_INTERFACES[@]} -eq 0 ]; then
        echo -e "${RED}[!]${NC} No monitor interfaces found. Returning to menu..."
        sleep 0.8
        prompt_to_continue
    fi

    select_interface_disable
}

# Select an interface to disable
select_interface_disable() {
    echo -e "${GREEN}[✓]${NC} Monitor-mode interfaces found!"
    echo -e "${GREEN}[*]${NC} Available monitor interfaces:"
    echo
    sleep 0.8

    for i in "${!MONITOR_INTERFACES[@]}"; do
        entry=${MONITOR_INTERFACES[$i]}
        iface_name=${entry%%:*}
        method=${entry##*:}
        echo -e "    ${GREEN}[$((i+1))]${NC} ${iface_name} (${method})"
        sleep 0.1
    done
    echo -e "    ${GREEN}[0]${NC} Go back"
    echo 
    sleep 0.3

    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Select an interface to disable: ")" selection
        if [[ "$selection" == "0" ]]; then
            prompt_to_continue
        elif [[ "$selection" =~ ^[1-9][0-9]*$ ]] && [ "$selection" -le "${#MONITOR_INTERFACES[@]}" ]; then
            SELECTED_INTERFACE="${MONITOR_INTERFACES[$((selection-1))]}"
            echo -e "${GREEN}[✓]${NC} Selected: $SELECTED_INTERFACE"
            sleep 0.3
            break
        else
            echo -e "${RED}[!]${NC} Invalid selection. Enter a number between 0 and ${#MONITOR_INTERFACES[@]}."
            sleep 0.3
        fi
    done

    disable_monitor_mode
}

# Disable monitor mode on selected interface
disable_monitor_mode() {
    INTERFACE_NAME=${SELECTED_INTERFACE%%:*}
    METHOD=${SELECTED_INTERFACE##*:}

    echo -e "${GREEN}[*]${NC} Disabling monitor mode on $INTERFACE_NAME using $METHOD..."
    sleep 0.8

    if [ "$METHOD" == "airmon-ng" ]; then
        airmon-ng stop "$INTERFACE_NAME" >/dev/null 2>&1
    else
        iw dev "$INTERFACE_NAME" del >/dev/null 2>&1
    fi

    echo -e "${GREEN}[✓]${NC} Monitor mode disabled on $INTERFACE_NAME."
    sleep 0.3

    after_monitor_options
}

# Show options after process is completed 
after_monitor_options() {
    echo -e "${GREEN}[*]${NC} Choose next operation:"
    echo
    echo -e "  ${GREEN}[1]${NC} Toggle monitor mode"
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
