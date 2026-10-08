#!/bin/bash

# --- Initial Setup ---
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_NAME=$(basename "$SCRIPT_PATH")
CURR_TTY="/dev/tty1"
REAL_USER=${SUDO_USER:-$USER}

exec > $CURR_TTY 2>&1
printf "\033c" > "$CURR_TTY"
export TERM=linux
export XDG_RUNTIME_DIR="/run/user/$(id -u)"

pkill -9 -f gptokeyb || true
if [ -f "/opt/inttools/gptokeyb" ]; then
    [[ -e /dev/uinput ]] && chmod 666 /dev/uinput 2>/dev/null || true
    export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
    /opt/inttools/gptokeyb -1 "$SCRIPT_NAME" -c "/opt/inttools/keys.gptk" >/dev/null 2>&1 &
fi

# --- Kiwix Specific Paths ---
BIN_PATH="/usr/local/bin/kiwix-serve"
KIWIX_DIR="/usr/local/share/kiwix"
PORT=80

# --- Cleanup & Exit Handling ---
ExitScript() {
    pkill -f "gptokeyb -1 $SCRIPT_NAME" || true
    printf "\033c\e[?25h" > "$CURR_TTY"
    exit 0
}
trap ExitScript EXIT SIGINT SIGTERM
printf "\e[?25l" > "$CURR_TTY"

# --- Helper Functions ---

GetLocalIP() {
    local ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    if [ -z "$ip" ]; then
        echo "No Network Connection"
    else
        echo "$ip"
    fi
}

GetRunningZim() {
    if pgrep -f "kiwix-serve" >/dev/null; then
        local cmd=$(ps aux | grep "[k]iwix-serve" | head -n 1)
        # Extract filename from command string
        local zim_file=$(echo "$cmd" | awk '{print $NF}')
        echo "$(basename "$zim_file")"
    else
        echo "None"
    fi
}

# --- Kiwix Installer Function ---
InstallKiwix() {
    dialog --infobox "Downloading kiwix-tools v3.5.0...\nThis requires an active Internet connection." 6 60
    
    mkdir -p "$KIWIX_DIR"
    cd "$KIWIX_DIR" || return

    wget -q --show-progress https://download.kiwix.org/release/kiwix-tools/kiwix-tools_linux-aarch64-3.5.0.tar.gz -O kiwix-tools.tar.gz

    if [ $? -ne 0 ]; then
        dialog --msgbox "ERROR:\n\nDownload failed! Please check your Internet connection." 8 50
        rm -f kiwix-tools.tar.gz
        return 1
    fi

    dialog --infobox "Extracting and installing binaries to /usr/local/bin..." 6 60
    tar -xvf kiwix-tools.tar.gz --strip-components=1 >/dev/null 2>&1
    chmod +x kiwix-serve kiwix-manage kiwix-read kiwix-search 2>/dev/null

    # Move binaries to standard system path
    mv kiwix-* /usr/local/bin/ 2>/dev/null
    rm -f kiwix-tools.tar.gz

    if [ -f "$BIN_PATH" ]; then
        dialog --msgbox "SUCCESS!\n\nKiwix v3.5.0 has been successfully installed." 8 50
    else
        dialog --msgbox "ERROR:\n\nInstallation failed during extraction or moving." 8 50
    fi
}

# --- Server Control Functions ---
StopKiwixServer() {
    if pgrep -f "kiwix-serve" >/dev/null; then
        pkill -f "kiwix-serve"
        dialog --msgbox "Kiwix Server stopped successfully." 6 45
    else
        dialog --msgbox "No Kiwix Server is currently running." 6 45
    fi
}

StartKiwixServer() {
    local zim_path="$1"
    local zim_name=$(basename "$zim_path")
    local ip_addr=$(GetLocalIP)

    # Check if online, and if not, set displayed IP to local
    if [ "$ip_addr" = "No Wi-Fi Connection" ]; then
        ip_addr="127.0.0.1"
    fi

    # Check if Port 80 is occupied (e.g. by nginx, lighttpd, or existing process)
    if ss -tuln | grep -q ":$PORT "; then
        dialog --msgbox "ERROR: Port $PORT is already in use!\n\nThis is usually caused by Remote Services or another web server active on the device." 9 60
        return 1
    fi

    # Stop any previous instance
    pkill -f "kiwix-serve" 2>/dev/null

    # Launch server in background
    "$BIN_PATH" --port=$PORT "$zim_path" >/dev/null 2>&1 &
    sleep 1

    if pgrep -f "kiwix-serve" >/dev/null; then
        dialog --msgbox "SERVER STARTED!\n\nServing: $zim_name\n\nAccess it on your browser at:\nhttp://$ip_addr" 10 55
    else
        dialog --msgbox "ERROR:\n\nFailed to start Kiwix server." 7 45
    fi
}

# --- Main UI Loop ---
while true; do
    # System Status Checks
    STATUS_KIWIX="\Z1[MISSING]\Zn"
    [ -f "$BIN_PATH" ] && STATUS_KIWIX="\Z2[INSTALLED]\Zn"

    RUNNING_ZIM=$(GetRunningZim)
    CURRENT_IP=$(GetLocalIP)

    # Find ZIM files across standard storage locations
    zim_files=()
    while IFS= read -r file; do
        [ -f "$file" ] && zim_files+=("$file")
    done < <(find /roms /roms2 /storage -type f -name "*.zim" 2>/dev/null)

    # Build Menu Options
    menu_options=()
    if [ ! -f "$BIN_PATH" ]; then
        menu_options+=(1 "Install Kiwix Server Tools (v3.5.0)")
    else
        if [ "$RUNNING_ZIM" != "None" ]; then
            menu_options+=(1 "Stop Active Server")
        fi
        
        menu_options+=(2 "Rescan for .ZIM Files")

        # Dynamically add available ZIMs to the list
        idx=3
        for zim in "${zim_files[@]}"; do
            menu_options+=("$idx" "Serve: $(basename "$zim")")
            ((idx++))
        done
    fi

    SELECTION=$(dialog --colors \
        --backtitle "R36S Kiwix Server Manager by SjslTech" \
        --title " KIWIX SERVER MANAGER " \
        --cancel-label "Exit" \
        --menu "Status: $STATUS_KIWIX\nIP Address: $CURRENT_IP\nActive ZIM: $RUNNING_ZIM\n\nChoose an action:" 18 70 8 \
        "${menu_options[@]}" --output-fd 1)

    exit_code=$?
    [ $exit_code -ne 0 ] && ExitScript

    case "$SELECTION" in
        1)
            if [ ! -f "$BIN_PATH" ]; then
                InstallKiwix
            else
                StopKiwixServer
            fi
            ;;
        2)
            dialog --infobox "Scanning for .zim files..." 5 40
            sleep 1
            ;;
        *)
            # Map selected option index back to array entry
            selected_index=$((SELECTION - 3))
            selected_zim="${zim_files[$selected_index]}"
            
            if [ -n "$selected_zim" ]; then
                StartKiwixServer "$selected_zim"
            fi
            ;;
    esac
done