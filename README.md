# SSID-Hunter (Thesis Project Wi-Fi Attack Scripts)

## Overview

**SSID-Hunter** is a collection of Bash scripts developed as part of a thesis project on wireless network security. These scripts automate various Wi-Fi penetration testing tasks and attacks, including enabling monitor mode, capturing traffic, generating network graphs, performing deauthentication and WEP/WPA/WPS attacks, and setting up rogue access points. The toolkit is designed for educational and authorized security testing purposes, providing an interactive menu-driven interface to execute each attack or utility.

## Scripts Overview

### Main Scripts

* **`start.sh`** – **Launcher & Menu:** The entry-point script. It must be run as root and will verify/install required tools (Aircrack-ng suite, Reaver, etc.) and prepare the environment (e.g. downloading wordlists, OUI database). It then presents an interactive **main menu** with options to toggle monitor mode, capture packets, generate graphs, look up vendors, or enter the attack menu. All other scripts are launched through this menu system.
* **`attack_mode.sh`** – **Attack Mode Menu:** Provides a submenu for selecting specific wireless attacks. It groups attacks by category (WPA/WPA2, WPS, WEP, Rogue AP) and prompts the user to choose an attack to execute. Selecting an option will call the corresponding script from the `Attacks/` directory (or return to the main menu).

### Attack Scripts (`Attacks/` directory)

* **`common.sh`** – *Shared Library:* Contains common functions and routines used by multiple attack scripts. This includes checking for root privileges, selecting a monitor-mode interface, prompting to start/stop packet captures, and returning to menus. (This script is sourced by others and not run on its own.)
* **`arp_attack.sh`** – **WEP ARP Replay Attack:** Implements an ARP Request Replay attack against WEP networks. It prompts for a target AP BSSID and a client MAC address, then uses `aireplay-ng -3` to inject ARP requests. This flood of injected packets forces the AP to generate new IVs, which can be captured and later used to crack the WEP key. The script opens a new terminal running the attack and allows the user to stop it, then offers to run another round or return to the menu.
* **`cafe_attack.sh`** – **Caffe Latte Attack (WEP):** Automates the “Caffe Latte” WEP attack. It requires a client previously connected to the target WEP network. The script asks for the target AP’s BSSID, a client’s MAC, and the network ESSID and channel. It then uses `aireplay-ng -6` to obtain a WEP keystream fragment and `airbase-ng` to spawn a fake AP with the same SSID/BSSID. An optional deauthentication can be sent to lure the client to connect to the rogue AP, at which point the client’s traffic can be captured to recover the WEP key. After running, the script stops the fake AP and any deauth process, indicating the attack is complete.
* **`crack_pass.sh`** – **Password Recovery Tool:** A post-capture cracking assistant for Wi-Fi credentials. It scans the `Captures/` folder for capture files (WEP IVs, WPA handshakes `.cap` or Hashcat `.22000` files, or enterprise `.creds` files) and lets the user pick one. It then offers multiple cracking methods:

  * WPA/WPA2 **dictionary attack** using `aircrack-ng` (requires selecting a wordlist from `/opt/passwords`).
  * WEP **key crack** using `aircrack-ng` (for .cap or .iv files collected from WEP attacks).
  * WPA/WPA2 **offline crack** using `cowpatty` (requires specifying the network SSID and a wordlist, used for WPA handshake files).
  * **Hashcat** attack for WPA-EAP (Enterprise) or WPA-PMKID captures – If an enterprise `.creds` file is selected (MS-CHAPv2 hash), it uses Hashcat mode 5500; if a `.22000` WPA handshake file is selected, it uses mode 22000.
    This script streamlines trying the appropriate tool to recover passwords or keys from captured data. After attempting a crack, it allows the user to go back or try another file.
* **`deauthentication.sh`** – **Deauth Attack:** Performs a deauthentication (disassociation) flood against a target AP. The user inputs the target BSSID and an optional client MAC (if no client is specified, all clients will be targeted), as well as the number of deauth packets to send. The script then uses `aireplay-ng --deauth` to transmit the specified number of deauthentication frames, kicking the client(s) off the network (note: this attack is effective on WPA/WPA2, but **will not** work on WPA3 networks). After sending the packets, it confirms completion and offers to run another deauth or return to the menu.
* **`enterprise_attack.sh`** – **Evil Twin for WPA-Enterprise:** Automates setting up a rogue AP to spoof an enterprise (802.1X) Wi-Fi network. *Requires two wireless interfaces.* The script generates necessary certificates on the fly using OpenSSL (creates a CA and server certificate), and writes a hostapd configuration enabling **hostapd-mana** in “enterprise WPE” mode. The user is prompted for the ESSID of the target network and a password to use for the fake EAP authentication (this should match what the rogue server expects). It then launches `hostapd-mana` on a secondary interface (`wlan1`) to act as the Evil Twin AP. The tool can optionally deauthenticate a client from the real AP (using a brief `aireplay-ng` deauth burst) to force reconnection to the fake AP. When a victim client connects and attempts authentication, **hostapd-mana** will capture their credentials (MSCHAPv2 challenge-response) and save them to a `credentials.creds` file. Upon stopping the attack, the script cleans up generated cert files and highlights that the captured credentials can later be cracked (e.g. via Hashcat in the `crack_pass.sh` tool).
* **`frag_attack.sh`** – **WEP Fragmentation Attack:** Executes a fragmentation attack on a WEP network. The user provides a target BSSID and a client MAC. The script uses `aireplay-ng -5` to inject fragments and capture a “keystream” file (`.xor`) along with a chosen packet `.cap`. It monitors the output for successful capture of the fragment. Once a keystream is obtained, it automatically uses `packetforge-ng` to create a forged ARP packet using the captured keystream and prompts the user to start reinjection. It then uses `aireplay-ng -2` to replay the forged ARP, generating a flood of new IVs from the AP. The user is asked if they want to also start a standard ARP replay (`aireplay-ng -3`) in parallel to accelerate IV collection. The attack runs until the user enters “stop,” after which all `aireplay-ng` processes are killed. (The collected IVs can later be used with `crack_pass.sh` to retrieve the WEP key.)
* **`korek_attack.sh`** – **Korek Chop-Chop Attack (WEP):** Automates the Korek “Chop-Chop” attack, which, like fragmentation, obtains a WEP keystream. The process is very similar to the fragmentation script: it uses `aireplay-ng -4` (chop-chop) to cut a packet and derive a `.xor` keystream and a packet file, then proceeds to forge an ARP packet with `packetforge-ng`. The forged packet is injected with `aireplay-ng -2` and the user can choose to run an ARP replay (`-3`) simultaneously to boost traffic. The script continuously runs until “stop” is entered, then cleans up. Essentially, this attack provides another method to generate IVs on WEP networks, especially if fragmentation fails – the ultimate goal is to gather enough IVs for cracking.
* **`mana_attack.sh`** – **Mana Rogue AP Attack (WPA Personal):** Sets up a rogue access point for WPA/WPA2 **personal** networks using the Mana toolkit. *Requires two Wi-Fi adapters.* The user provides an SSID to spoof (typically one that target clients are probing for). The script creates a minimal hostapd config for `hostapd-mana` on a secondary interface (`wlan1`), using an open/WPA2 network with a dummy passphrase. It launches the fake AP (`hostapd-mana`) which will accept client connections (clients may see a security warning if expecting a different network). When a client attempts to connect, a WPA 4-way handshake is captured (with an arbitrary passphrase since the real key is unknown). Upon stopping, the script uses `hcxhash2cap` and `hcxpcapngtool` (from **hcxtools**) to convert the captured handshake (`.hccapx`) into a standard `.pcap` and then into a Hashcat `.22000` hash file. The resulting handshake file (stored in `Captures/`) can be loaded into the cracking tool (`crack_pass.sh` or other password crackers) to brute-force the actual WPA passphrase.
* **`offline_attack.sh`** – **WPS Pixie-Dust Attack (Offline):** Targets WPS-enabled networks using the Pixie Dust vulnerability (an offline WPS PIN recovery). The user inputs the target AP’s BSSID and channel. The script then runs `reaver -K 1` (Pixie Dust mode) for up to 5 minutes on the selected target. If the Pixie Dust attack succeeds, it will extract the WPS PIN from the `reaver` output. The script then automatically runs a second `reaver` pass using the found PIN to retrieve the AP’s WPA/WPA2 PSK (password). On success it prints out the discovered **WPS PIN**, **WPA PSK**, and **SSID**. If it fails to find a pin, it notifies the user. After completion, the user can choose to repeat the Pixie attack or return to menu.
* **`online_attack.sh`** – **WPS PIN Brute-Force (Online):** Attempts to crack a WPS PIN by brute force using `reaver` without Pixie Dust (online method). The user supplies the target BSSID and channel, then the script runs `reaver -vvv` on the target for a fixed duration (\~5 minutes timeout by default). If `reaver` manages to find the correct WPS PIN and retrieve the WPA passphrase within that time, those are displayed (PIN, PSK, SSID). The script reminds the user that too many wrong attempts can lock the WPS on the AP. After the attack (or timeout), it reports if a PIN was found or not and marks the attack complete, allowing the user to try again or return to the main menu.

### Utility Scripts (`Utils/` directory)

* **`enable_monitor_mode.sh`** – **Monitor Mode Manager:** Helps enable or disable monitor mode on wireless interfaces. Running as root, it scans for available Wi-Fi interfaces and presents options:

  * *Enable monitor mode:* User selects one of the detected interfaces. The script can kill common interfering processes (using `airmon-ng check kill`) if the user agrees. It then offers two methods to enable monitoring: via `airmon-ng` or using the `iw` command to create a monitor interface (recommended for WPS attacks). The chosen interface is put into monitor mode (e.g., producing a `wlan0mon` or `mon0` interface), and confirmation is shown.
  * *Disable monitor mode:* If any monitor interfaces are active, it lists them (and how they were created). The user selects an interface to disable, and the script will either `airmon-ng stop` it or remove it via `iw dev ... del`, depending on how it was created.
    After enabling/disabling, the script offers to toggle again or go back to the main menu (`start.sh`). This utility simplifies managing interface modes during the testing session.
* **`capture_packets.sh`** – **Packet Capture Utility:** Provides an interactive way to capture Wi-Fi traffic using `airodump-ng`. The menu options allow:

  1. **View saved capture files** – Lists files in the `Captures/` directory (e.g. `.cap`, `.csv`, `.netxml`) and lets the user open them. `.cap` files launch in Wireshark (if available), and other text-based logs open with the default viewer.
  2. **Scan entire band** – User chooses a wireless interface in monitor mode, then selects band (2.4GHz or 5GHz) to capture on all channels of that band.
  3. **Scan specific channel** – User chooses a monitor interface and specifies a single channel (1–14) to capture on.
     For options 2 or 3, it then asks if the capture should be saved to file. If yes, it lets the user pick an output format (CSV, PCAP (`.cap`), GPS, Kismet netxml/csv, or “all”) and a filename; files are saved under `Captures/`. The script then launches `airodump-ng` with the chosen parameters (in the current terminal) and displays a message that pressing **Ctrl+C** will stop the capture. After stopping, it returns to a prompt where the user can start a new capture or go back to main menu.
* **`graph_generator.sh`** – **Wireless Graph Generator:** Uses `airgraph-ng` to create visual graphs from captured data. Two graph types are supported:

  * **Clients-to-AP Graph (CAPR):** Shows relationships between clients and access points (who is connected to whom) from a capture.
  * **Common Probe Graph (CPG):** Shows networks that clients are probing in common, useful to identify popular SSIDs or shared client activity.
    The script looks for airodump CSV files in the `Captures/` directory (standard `airodump-ng` CSV output). The user can select a CSV file from the list, then choose which graph to generate. The graph image is created in a `Graphs/` directory (the script will create it if needed) with a user-provided name (PNG format). If graphs have already been generated, the utility can also list existing `.png` files in `Graphs/` and allow the user to open them (using the default image viewer). After generating a graph, the user can create another or return to the main menu. *(Note: Only capture files in CSV format (excluding Kismet’s specialized CSV) are supported by airgraph-ng.)*
* **`vendor_lookup.sh`** – **MAC Vendor Lookup:** A simple tool to identify a network device’s manufacturer from its MAC address prefix. It requires the IEEE OUI database file (`/var/lib/ieee-data/oui.txt` – which the main `start.sh` will ensure is installed via the `ieee-data` package). The script prompts for a MAC prefix in `XX-XX-XX` format (first 3 bytes of a MAC). If the input is valid, it searches the OUI file (case-insensitive) for a matching prefix and outputs the registered vendor name. If no match is found, it notifies the user. This lookup can be repeated multiple times until the user enters `0` to return to the main menu. It’s useful for identifying device types or manufacturers from captured MAC addresses.

## Usage

To use this toolkit, clone or download the repository containing all the scripts, then run the main launcher:

```bash
sudo ./start.sh
```

Ensure you run as **root**, since nearly all operations (monitor mode, packet injection, etc.) require root privileges. Upon launch, **SSID-Hunter** will display its main menu. Navigate through the menu by entering the number of the desired option. For example, to perform a Pixie Dust WPS attack, you would choose **“Attack mode”** from the main menu, then select the **“Offline Pixie dust attack”** option, and follow the interactive prompts for target details.

All scripts are interactive and guide you with on-screen instructions or notices (e.g., warnings about legal usage, prerequisites like enabling monitor mode, etc.). After an operation completes, the scripts typically offer options to repeat the action or return to the appropriate menu. You can exit the tool via the menu at any time by selecting the **Exit** option (or pressing Ctrl+C in some sub-scripts to abort an ongoing attack).

**Note:** It’s recommended to use these scripts in a Linux environment with a wireless card that supports monitor mode and packet injection. For certain attacks (like Rogue AP/Mana and Enterprise), you need two wireless adapters (one to maintain an AP while the other remains in monitor mode). The interface selection dialogs will help you choose the right adapters.

## Installation & Requirements

**System Requirements:** A Linux system (tested on Kali Linux and similar pen-test distributions) with Bash shell. A GUI terminal (the scripts use `gnome-terminal` to spawn some attack windows) is suggested for best experience.

**Hardware:** At least one wireless network interface capable of monitor mode and injection. Two such interfaces are needed for Rogue AP attacks (one for the fake AP, one for monitoring/deauth).

**Dependencies:** The toolkit relies on a number of external tools and programs:

* **Aircrack-ng suite:** `airmon-ng`, `airodump-ng`, `aireplay-ng`, `airbase-ng`, `aircrack-ng`, and `packetforge-ng` for various Wi-Fi attacks and capture operations.
* **Airgraph-ng:** for generating graphical network maps from captures.
* **Reaver** (with PixieDust support): for WPS PIN brute-force and Pixie Dust attacks.
* **PixieWPS:** (usually integrated with Reaver for Pixie Dust).
* **cowpatty:** for offline WPA handshake cracking.
* **Hashcat & hcxtools:** used in processing and cracking captured handshakes (the scripts use `hcxhash2cap`/`hcxpcapngtool` for conversion and call `hashcat` for cracking WPA-EAP or PMKID hashes).
* **hostapd-mana:** a specialized version of hostapd for performing Evil Twin attacks (rogue AP for Mana and Enterprise attacks).
* **OpenSSL:** used in enterprise attack to generate certificates on the fly.
* **tcpdump:** used in fragmentation/chopchop attacks to parse packet contents.
* **iw** and **ifconfig:** for managing interfaces (alternative to airmon-ng).
* **Git:** used by `start.sh` to clone a repository of password wordlists to `/opt/passwords` (for use in cracking).
* **ieee-data (OUI database):** provides the `/var/lib/ieee-data/oui.txt` file for MAC vendor lookup.
* **gnome-terminal:** used to launch certain attacks in separate windows (ensures long-running capture/attack doesn’t block the menu script).

**Installation:** There isn’t a traditional installation process – simply ensure all the above dependencies are installed on your system. When you run `start.sh`, it will automatically check for most of these tools and attempt to install any that are missing:

* On Debian/Ubuntu/Kali it will use `apt-get`, on Red Hat/CentOS it will use `yum`, and on Arch it will use `pacman` to install packages. (If your system uses a different package manager or if some tools are not available via those, you may need to install them manually.)
* The script will also automatically git-clone a wordlists repository (common password lists) into `/opt/passwords` if no wordlists are found, to assist with WPA/WPS password cracking.

After ensuring dependencies, simply make sure all `.sh` files are executable (`chmod +x *.sh` if necessary) and run `start.sh` as described. The directory structure should be preserved (scripts expect the `Attacks/` and `Utils/` subfolders to be in the same directory as `start.sh`).

Always use these tools responsibly and only on networks you have permission to test. The attacks implemented can be disruptive (e.g., deauthing users, overwhelming APs with traffic, or brute-forcing credentials).

## License

This project is licensed under the **MIT License**. Feel free to use, modify, and distribute the code in accordance with the license terms. See the `LICENSE` file for details.

## Author

**Nichifor Costin** – *Thesis Author & Tool Developer*
Email: costin.nk@gmail.com

*Developed as part of a master’s thesis in cybersecurity at \[Universitatea "Ovidius" Constanța].*
