# common.sh — library of shared functions for all scripts


# Check for root
require_root() {
	if [[ $EUID -ne 0 ]]; then
    	echo -e "${RED}[!]${NC} This script must be run as root." >&2
    	exit 1
	fi
}


# Go back to attack mode main menu
go_back() {
    echo -e "${GREEN}[✓]${NC} Returning to main menu..."
    sleep 0.5
    exec ./attack_mode.sh
}

# Checks for interfaces in monitor mode and shows the to the user
check_monitor_interfaces() {
    echo -e "${GREEN}[*]${NC} Checking for interfaces in monitor mode..."
    sleep 0.5

    MON_INTERFACES=($(iw dev 2>/dev/null \
        | awk '$1=="Interface"{iface=$2} $1=="type"&&$2=="monitor"{print iface}'))
    if [ ${#MON_INTERFACES[@]} -eq 0 ]; then
        echo -e "${RED}[!]${NC} No monitor interfaces found. Returning to main menu..."
        sleep 0.5
        go_back
    fi

    echo -e "${GREEN}[✓]${NC} Monitor-mode interfaces found:"
    echo
    for i in "${!MON_INTERFACES[@]}"; do
        echo -e "  ${GREEN}[$((i+1))]${NC} ${MON_INTERFACES[$i]}"
        sleep 0.1
    done
    echo -e "  ${GREEN}[0]${NC} Go back"
    echo

    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Choose an option:") " idx
        if [[ "$idx" == "0" ]]; then
            go_back
        elif [[ "$idx" =~ ^[0-9]+$ ]] && (( idx>=1 && idx<=${#MON_INTERFACES[@]} )); then
            MONITOR_INTERFACE=${MON_INTERFACES[$((idx-1))]}
            echo -e "${GREEN}[✓]${NC} Selected: $MONITOR_INTERFACE"
            sleep 0.5
            break
        else
            echo -e "${RED}[!]${NC} Invalid. Choose 0-${#MON_INTERFACES[@]}"; sleep 0.3
        fi
    done
}




# Offer capture with band/channel choice
ask_capture_choice() {

    local mode_arg="$1"


    echo -e "${GREEN}[*]${NC} Capture options:"
    echo
    echo -e "  ${GREEN}[1]${NC} Capture entire band"
    sleep 0.1
    echo -e "  ${GREEN}[2]${NC} Capture specific channel"
    sleep 0.1
    echo -e "  ${GREEN}[0]${NC} Skip capture"
    sleep 0.1
    echo

    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Choose an option:") " mode
        case "$mode" in
            1) scan_mode="band"; break ;;  
            2) scan_mode="channel"; break ;;  
            0) scan_mode="none"; break ;;  
            *) echo -e "${RED}[!]${NC} Invalid. Choose 0-2."; sleep 0.3 ;;  
        esac
    done

    if [[ "$scan_mode" != "none" ]]; then
        if [[ "$mode_arg" == "wps" ]]; then
            # we pass "wps" through so select_capture_options will add --wps
            select_capture_options "wps"
        else
            select_capture_options 
        fi
    fi
}


# Capture options
select_capture_options() {
    if [[ "$scan_mode" == "band" ]]; then
        while true; do
            read -rp "$(echo -e "${GREEN}[?]${NC} Band (a = 2.4GHz, g = 5GHz):") " band
            if [[ "$band" =~ ^(a|g)$ ]]; then
                scan_flag="--band $band"
                echo -e "${GREEN}[✓]${NC} Band set: $band"; sleep 0.3; break
            else
                echo -e "${RED}[!]${NC} Invalid. Enter a or g."; sleep 0.3
            fi
        done
    else
        while true; do
            read -rp "$(echo -e "${GREEN}[?]${NC} Channel (1-14):") " channel
            if [[ "$channel" =~ ^[0-9]+$ ]] && (( channel>=1 && channel<=165 )); then
                scan_flag="-c $channel"
                echo -e "${GREEN}[✓]${NC} Channel set: $channel"; sleep 0.3; break
            else
                echo -e "${RED}[!]${NC} Invalid. 1-14 only."; sleep 0.3
            fi
        done
    fi

    # $1 may be "wps"; $scan_mode still controls band vs channel
    local mode_arg="$1"
    local wps_mode=""
    
    if [[ "$mode_arg" == "wps" ]]; then
        wps_mode="--wps"
        echo -e "${GREEN}[✓]${NC} WPS scan enabled"
        sleep 0.3
    fi

    ask_save_to_file

    echo -e "${GREEN}[*]${NC} Launching capture on $MONITOR_INTERFACE..."
    capture_command="sudo airodump-ng $wps_mode $scan_flag $MONITOR_INTERFACE $output_format"
    gnome-terminal -- bash -c "$capture_command; exec bash" &

    sleep 0.5
}

# Prompt to save capture output
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
}

# Stop capture if desired
ask_stop_capture() {
    while true; do
        read -rp "$(echo -e "${GREEN}[?]${NC} Do you want to stop capturing packets? (yes/no): ")" stop
        if [[ "$stop" == "yes" ]]; then
            sudo pkill -f airodump-ng
            echo -e "${GREEN}[✓]${NC} Capture stopped."
            sleep 0.3
            break
        elif [[ "$stop" == "no" ]]; then
            break
        else
            echo -e "${RED}[!]${NC} Invalid option. Please type 'yes' or 'no'."
            sleep 0.3
        fi
    done
}
