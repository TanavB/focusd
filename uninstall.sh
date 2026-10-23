#!/usr/bin/env bash

GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"

echo -e "${YELLOW}Starting Focusd Uninstaller...${RESET}"

PID_FILE="/tmp/focusd-$UID.txt"
if [[ -f "$PID_FILE" ]] && kill -0 "$(<"$PID_FILE")" 2>/dev/null; then
    echo -e "${YELLOW}Stopping active Focusd session...${RESET}"
    kill -SIGTERM "$(<"$PID_FILE")" 2>/dev/null
fi

sudo -v
if [[ -f "/etc/sudoers.d/focusd" ]]; then
    echo -e "${YELLOW}Removing sudoers permissions...${RESET}"
    sudo rm -f "/etc/sudoers.d/focusd"
fi

echo -e "${YELLOW}Removing binaries and scripts...${RESET}"
rm -rf "$HOME/.local/share/focusd"
rm -f "$HOME/.local/bin/focusd-toggle"
rm -f "$HOME/.local/bin/focusd-stats"
rm -f "$HOME/.local/bin/focusd-config"

echo -e "${YELLOW}Removing desktop launchers...${RESET}"
rm -f "$HOME/.local/share/applications/focusd.desktop"
rm -f "$HOME/.local/share/applications/focusd-stats.desktop"
rm -f "$HOME/.local/share/applications/focusd-config.desktop"

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null
fi

rm -f "/tmp/focusd-$UID.txt" "/tmp/focusd-dns-$UID.txt" "/tmp/focusd_web_$UID.txt"

# Read from /dev/tty if stdin is piped via curl
confirm=""
if [ -t 0 ]; then
    read -r -p "Do you want to delete session logs and configurations in ~/.config/focusd? [y/N]: " confirm
elif [ -e /dev/tty ]; then
    read -r -p "Do you want to delete session logs and configurations in ~/.config/focusd? [y/N]: " confirm < /dev/tty
fi

if [[ "$confirm" =~ ^[Yy]$ ]]; then
    rm -rf "$HOME/.config/focusd"
    echo -e "${YELLOW}Configuration and logs deleted.${RESET}"
fi

sudo -k
echo -e "${GREEN}Focusd has been cleanly uninstalled.${RESET}"
