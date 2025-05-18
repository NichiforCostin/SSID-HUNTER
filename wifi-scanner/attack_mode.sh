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

# Display attack options and handle user selection
choose_attack() {
  clear
  echo
  echo -e "${GREEN}==============================================${NC}"
  echo -e "${BOLD}${GREEN}           Attack Mode Main Menu            ${NC}${BOLD}${NC}"
  echo -e "${GREEN}==============================================${NC}"
  echo

  echo -e "${RED}[!]${NC} Make sure you have a Wi-Fi interface that supports monitor mode and packet injection."
  echo -e "${RED}[!]${NC} LEGAL NOTICE: These tools are provided for educational and authorized security testing only."
  echo
  sleep 0.5

  echo -e "${GREEN}[*]${NC} Available attacks:"
  sleep 0.3
  echo

  echo -e "${GREEN}-- WPA/WPA2 Attacks --${NC}"
  echo
  echo -e "    ${GREEN}[1]${NC} Password recovery"
  sleep 0.1
  echo -e "    ${GREEN}[2]${NC} Deauthentication attack"
  sleep 0.1
  echo

  sleep 0.3
  echo -e "${GREEN}-- WPS Attacks --${NC}"
  echo
  echo -e "    ${GREEN}[3]${NC} Offline Pixie Dust attack"
  sleep 0.1
  echo -e "    ${GREEN}[4]${NC} Online PIN guess attack"
  sleep 0.1
  echo

  sleep 0.3
  echo -e "${GREEN}-- WEP Attacks --${NC}"
  echo
  echo -e "    ${GREEN}[5]${NC} ARP request replay attack"
  sleep 0.1
  echo -e "    ${GREEN}[6]${NC} Fragmentation attack"
  sleep 0.1
  echo -e "    ${GREEN}[7]${NC} Korek Chop Chop attack"
    sleep 0.1
  echo -e "    ${GREEN}[8]${NC} Cafe Latte attack"
  sleep 0.1
  echo

  sleep 0.3
  echo -e "${GREEN}-- Rogue AP Attacks --${NC}"
  echo
  echo -e "${RED}[!]${NC} Rogue AP attacks require two wireless interfaces"
  echo
  echo -e "    ${GREEN}[9]${NC} Mana attack"
  sleep 0.1
  echo -e "    ${GREEN}[10]${NC} Enterprise attack"
  sleep 0.1
  echo

  sleep 0.3
  echo -e "    ${GREEN}[0]${NC} Go back"
  echo

  while true; do
    read -rp "$(echo -e "${GREEN}[?]${NC} Select a attack ")" choice
    case "$choice" in
      1)
        echo -e "${GREEN}[✓]${NC} Launching Password recovery..."
        sleep 0.5
        ./Attacks/crack_pass.sh
        break
        ;;
      2)
        echo -e "${GREEN}[✓]${NC} Launching Deauthentication attack..."
        sleep 0.5
        ./Attacks/deauthentication.sh
        break
        ;;
      3)
        echo -e "${GREEN}[✓]${NC} Launching Offline Pixie Dust attack..."
        sleep 0.5
        ./Attacks/offline_attack.sh
        break
        ;;
      4)
        echo -e "${GREEN}[✓]${NC} Launching Online PIN guess attack..."
        sleep 0.5
        ./Attacks/online_attack.sh
        break
        ;;
      5)
        echo -e "${GREEN}[✓]${NC} Launching ARP request replay attack..."
        sleep 0.5
        ./Attacks/arp_attack.sh
        break
        ;;
      6)
        echo -e "${GREEN}[✓]${NC} Launching Fragmentation attack..."
        sleep 0.5
        ./Attacks/frag_attack.sh
        break
        ;;
      7)
        echo -e "${GREEN}[✓]${NC} Launching Korek Chop Chop attack..."
        sleep 0.5
        ./Attacks/korek_attack.sh
        break
        ;;
      8)
        echo -e "${GREEN}[✓]${NC} Launching Cafe Latte attack..."
        sleep 0.5
        ./Attacks/cafe_attack.sh
        break
        ;;
      9)
        echo -e "${GREEN}[✓]${NC} Launching Mana attack..."
        sleep 0.5
        ./Attacks/mana_attack.sh
        break
        ;;
      10)
        echo -e "${GREEN}[✓]${NC} Launching Enterprise attack..."
        sleep 0.5
        ./Attacks/enterprise_attack.sh
        break
        ;;
      0)
        echo -e "${GREEN}[✓]${NC} Returning to main menu..."
        sleep 0.5
        exec ./start.sh
        ;;
      *)
        echo -e "${RED}[!]${NC} Invalid choice. Please select 0-10"
        sleep 0.3
        ;;
    esac
  done
}

# Main entry point: start attack mode menu
main() {
  choose_attack
}

main
