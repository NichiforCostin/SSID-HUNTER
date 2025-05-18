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

# List of required services
dependencies=(airmon-ng airodump-ng airgraph-ng aireplay-ng airbase-ng aircrack-ng packetforge-ng cowpatty reaver git tcpdump)

# Path to files
oui_file="/var/lib/ieee-data/oui.txt"
wordlist_dir="/opt/passwords"

# Detect package manager once and set install/update commands
detect_package_manager() {
  if command -v apt-get &>/dev/null; then
    PKG_INSTALL=('apt-get' 'install' '-y')
    PKG_UPDATE=('apt-get' 'update')
  elif command -v yum &>/dev/null; then
    PKG_INSTALL=('yum' 'install' '-y')
    PKG_UPDATE=()
  elif command -v pacman &>/dev/null; then
    PKG_INSTALL=('pacman' '-Sy' '--noconfirm')
    PKG_UPDATE=()
  else
    echo -e "${RED}[!]${NC} No supported package manager found. Please install dependencies manually." >&2
    exit 1
  fi
}

# Install a package silently, then verify installation
install_pkg() {
  local pkg="$1"
  echo -e "${GREEN}[*]${NC} Installing ${BOLD}$pkg${NC}..."
  if [ ${#PKG_UPDATE[@]} -ne 0 ]; then
    "${PKG_UPDATE[@]}" > /dev/null 2>&1
  fi
  "${PKG_INSTALL[@]}" "$pkg" > /dev/null 2>&1
  if command -v "$pkg" &>/dev/null; then
    echo -e "${GREEN}[✓]${NC} ${BOLD}$pkg${NC} installed successfully."
  else
    echo -e "${RED}[✗]${NC} Failed to install ${BOLD}$pkg${NC}. Please install manually." >&2
    exit 1
  fi
  sleep 0.3
}

# Download password wordlists into /opt/passwords via sparse git checkout
download_password_wordlists() {
  echo -e "${GREEN}[*]${NC} Downloading password wordlists to ${wordlist_dir}..."
  sleep 0.3
  # ensure git is present
  if ! command -v git &>/dev/null; then
    install_pkg git
  fi
  sudo rm -rf /opt/wordlists-temp "$wordlist_dir"
  sudo git clone --depth=1 --filter=blob:none --sparse \
    https://github.com/kkrypt0nn/wordlists.git /opt/wordlists-temp \
    > /dev/null 2>&1
  pushd /opt/wordlists-temp >/dev/null
    sudo git sparse-checkout set wordlists/passwords
    sudo mv wordlists/passwords "$wordlist_dir"
  popd >/dev/null
  sudo rm -rf /opt/wordlists-temp
  echo -e "${GREEN}[✓]${NC} Wordlists are now in ${wordlist_dir}"
  sleep 0.3
}

# Verify and install dependencies interactively
check_dependencies() {
  echo
  echo -e "${BOLD}${GREEN}-- Checking Dependencies --${NC}"
  echo
  sleep 0.3

  for cmd in "${dependencies[@]}"; do
    echo -en "${GREEN}[*]${NC} Checking for ${BOLD}$cmd${NC}... "
    sleep 0.1
    if command -v "$cmd" &>/dev/null; then
      echo -e "${GREEN}[✓]${NC}"
    else
      echo -e "${RED}[✗]${NC}"
      install_pkg "$cmd"
    fi
  done

  echo -en "${GREEN}[*]${NC} Checking for OUI database file... "
  if [ -f "$oui_file" ]; then
    echo -e "${GREEN}[✓]${NC}"
  else
    echo -e "${RED}[✗]${NC}"
    install_pkg "ieee-data"
  fi

  echo -en "${GREEN}[*]${NC} Checking for password wordlists... "
  if [ -d "$wordlist_dir" ] && compgen -G "$wordlist_dir/*.txt" >/dev/null; then
    echo -e "${GREEN}[✓]${NC}"
  else
    echo -e "${RED}[✗]${NC}"
    download_password_wordlists
  fi

  echo
  sleep 0.5
}

# Display welcome banner
display_welcome() {
  clear
  echo -e "${GREEN}==============================================${NC}"
  echo -e "${BOLD}${GREEN}         Welcome to SSID-HUNTER v1.0      ${NC}${BOLD}${NC}"
  echo -e "${GREEN}==============================================${NC}"
  sleep 0.5
}

# Display main menu and handle user choice
choose_operation() {
  local options=(
    "Enable/disable monitor mode"
    "Start packet capture"
    "Generate packet graph"
    "Vendor lookup by MAC"
    "Attack mode"
  )

  echo -e "${GREEN}==============================================${NC}"
  echo -e "${BOLD}${GREEN}            SSID-HUNTER Main Menu           ${NC}${BOLD}${NC}"
  echo -e "${GREEN}==============================================${NC}"
  echo
  sleep 0.5

  for i in "${!options[@]}"; do
    echo -e "  ${GREEN}[$((i+1))]${NC} ${options[$i]}"
    sleep 0.1
  done
  echo -e "  ${GREEN}[0]${NC} Exit"
  echo
  sleep 0.5

  while true; do
    read -rp "$(echo -e "${GREEN}[*]${NC} Select an option: ")" option
    case "$option" in
      1) sleep 0.1; ./Utils/enable_monitor_mode.sh; break ;;
      2) sleep 0.1; ./Utils/capture_packets.sh;     break ;;
      3) sleep 0.1; ./Utils/graph_generator.sh;     break ;;
      4) sleep 0.1; ./Utils/vendor_lookup.sh;       break ;;
      5) sleep 0.1; ./attack_mode.sh;                break ;;
      0) echo -e "${GREEN}[✓]${NC} Goodbye!"; sleep 0.5; exit 0 ;;
      *) echo -e "${RED}[!]${NC} Invalid choice. Enter 0-${#options[@]}."; sleep 0.5 ;;
    esac
  done
}

# Main entry point to initialize and start the script
main() {
  detect_package_manager
  display_welcome
  check_dependencies
  choose_operation
}

main
