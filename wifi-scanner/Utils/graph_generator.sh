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

# Verify the existance of the Captures dir and looks for .csv files
check_captures_directory() {
    if [ ! -d "Captures" ]; then
        echo -e "${RED}[!]${NC} Captures directory does not exist. Returning to main menu..."
        sleep 0.8
        prompt_to_continue
    fi

    files=$(find Captures -maxdepth 1 -type f -name "*.csv" ! -name "*.kismet.csv" ! -name "*.log.csv")
    if [ -z "$files" ]; then
        echo -e "${RED}[!]${NC} No .csv capture files found. Returning to main menu..."
        sleep 0.8
        prompt_to_continue
    fi
}

# Lists and opens .png files in Graphs/
view_saved_graphs() {
    if [ ! -d "Graphs" ]; then
        echo -e "${RED}[!]${NC} No Graphs directory found. Returning to menu..."
        sleep 1.2
        prompt_to_continue
        return
    fi

    local files=(Graphs/*.png)
    if [ ! -e "${files[0]}" ]; then
        echo -e "${RED}[!]${NC} No graph images found in Graphs/. Returning to menu..."
        sleep 0.5
        prompt_to_continue
        return
    fi

    echo -e "${GREEN}[*]${NC} Available graph images:"
    echo
    for i in "${!files[@]}"; do
        echo -e "    ${GREEN}[$((i+1))]${NC} ${files[$i]##*/}"
        sleep 0.1
    done
    echo -e "    ${GREEN}[0]${NC} Go back"
    echo

    # Select Graph
    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Select a graph to open: ")" sel
        if [[ "$sel" == "0" ]]; then
            prompt_to_continue
            return
        elif [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= ${#files[@]} )); then
            local file_to_open="${files[$((sel-1))]}"
            echo -e "${GREEN}[✓]${NC} Opening ${file_to_open##*/}..."
            xdg-open "$file_to_open" >/dev/null 2>&1 &
            sleep 0.5
        else
            echo -e "${RED}[!]${NC} Invalid selection. Please choose 0-${#files[@]}."
            sleep 0.3
        fi
    done
}

# Show .csv files and let user choose one
choose_file() {
    local files=($(find Captures -maxdepth 1 -type f -name "*.csv" ! -name "*.kismet.csv" ! -name "*.log.csv"))

    echo -e "${GREEN}[*]${NC} Available .csv capture files:"
    echo
    for i in "${!files[@]}"; do
        echo -e "  ${GREEN}[$((i+1))]${NC} ${files[$i]##*/}"
        sleep 0.1
    done
    echo -e "  ${GREEN}[0]${NC} Go back"
    echo

    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Select a file: ")" idx
        if [[ "$idx" == "0" ]]; then
            prompt_to_continue
        elif [[ "$idx" =~ ^[0-9]+$ ]] && (( idx >= 1 && idx <= ${#files[@]} )); then
            selected_file="${files[$((idx-1))]}"
            echo -e "${GREEN}[✓]${NC} Selected file: ${selected_file##*/}"
            sleep 0.8
            break
        else
            echo -e "${RED}[!]${NC} Invalid option. Please select 0-${#files[@]}."
            sleep 0.3
        fi
    done
}

# Generează și salvează graficul folosind airgraph-ng
save_graph() {
    local mode="$1"
    [ ! -d "Graphs" ] && mkdir -p Graphs

    read -rp "$(echo -e "${GREEN}[?]${NC} Enter a name for the graph image (no extension): ")" graph_name

    graph_file="Graphs/${graph_name}.png"

    # Link către fișierul selectat pentru airgraph-ng
    ln -sf "$selected_file" selected_file.csv

    airgraph-ng -i selected_file.csv -g "$mode" -o "$graph_file" >/dev/null 2>&1
    if [[ "$mode" == "CAPR" ]]; then
        echo -e "${GREEN}[*]${NC} Generating Clients→AP graph..."
        sleep 0.5
    elif [[ "$mode" == "CPG" ]]; then
        echo -e "${GREEN}[*]${NC} Generating Common Probe graph..."
        sleep 0.5
    fi
    echo -e "${GREEN}[✓]${NC} Graph generated and saved as ${graph_file}"
    sleep 0.8
}

# Flux pentru graficul Clients→AP
clients_to_ap_graph() {
    echo -e "${GREEN}[*]${NC} Checking for .csv files..."
    sleep 0.5
    check_captures_directory
    choose_file
    save_graph "CAPR"
    after_graph_options
}

# Flux pentru graficul Common Probe
common_probe_graph() {
    echo -e "${GREEN}[*]${NC} Checking for .csv files..."
    sleep 0.5
    check_captures_directory
    choose_file
    save_graph "CPG"
    after_graph_options
}

# Oferă opțiunea de a genera alt grafic sau de a reveni
after_graph_options() {
    echo -e "${GREEN}[*]${NC} Choose next operation:"
    echo
    echo -e "  ${GREEN}[1]${NC} Create another graph"
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

# Show menu and options 
prompt_to_continue() {
    clear
    echo
    echo -e "${GREEN}==============================================${NC}"
    echo -e "${BOLD}${GREEN}            Graph Mode Main Menu            ${NC}${BOLD}${NC}"
    echo -e "${GREEN}==============================================${NC}"
    echo
    echo -e "${RED}[!]${NC} Graph creation works only on .csv files in Captures/"
    echo

    sleep 0.5 


    local options=("View saved graphs" "Clients to AP relationship graph" "Common Probe graph")
    for i in "${!options[@]}"; do
        echo -e "  ${GREEN}[$((i+1))]${NC} ${options[$i]}"
        sleep 0.1
    done
    echo -e "  ${GREEN}[0]${NC} Go back"
    echo

    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Select an option: ")" opt
        case $opt in
            1) view_saved_graphs; break ;;
            2) clients_to_ap_graph; break ;;
            3) common_probe_graph; break ;;
            0) go_back ;;
            *) echo -e "${RED}[!]${NC} Invalid option. Select 0-3."; sleep 0.3 ;;
        esac
    done
}

# Main entry point
main() {
    prompt_to_continue
}

main
