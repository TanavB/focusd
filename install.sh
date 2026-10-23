#!/usr/bin/env bash

GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"

sudo -v
while true; do sudo -n true; sleep 45; kill -0 "$$" || exit; done 2>/dev/null &
sudo apt update
sudo apt install -y curl jq zenity dnsmasq-base iptables iproute2 conntrack coreutils
PATH="$PATH:/usr/sbin:/sbin"
IPTABLES=$(type -P iptables)
IP6TABLES=$(type -P ip6tables)
DNSMASQ=$(type -P dnsmasq)
RESOLVECTL=$(type -P resolvectl)
SYSCTL=$(type -P sysctl)
CONNTRACK=$(type -P conntrack)
SS=$(type -P ss)
KILL=$(type -P kill)

touch "/tmp/focusd_sudoers"
chmod 666 "/tmp/focusd_sudoers"
echo "$USER ALL=(ALL) NOPASSWD: $IPTABLES, $IP6TABLES, $DNSMASQ, $RESOLVECTL, $SYSCTL, $CONNTRACK, $SS, $KILL" > "/tmp/focusd_sudoers"
if sudo visudo -cf "/tmp/focusd_sudoers"; then
	sudo install -m 0440 /tmp/focusd_sudoers /etc/sudoers.d/focusd
	rm -f "/tmp/focusd_sudoers"
else
	echo -e "${RED}Permission denied, no password cannot be set, exiting${RED}"
	rm -f "/tmp/focusd_sudoers"
	exit 1
fi

APP_LOC="$HOME/.local/share/focusd"
CONFIG_LOC="$HOME/.config/focusd"
BIN_LOC="$HOME/.local/bin"
DESKTOP_LOC="$HOME/.local/share/applications"
REPO_URL="https://raw.githubusercontent.com/TanavB/focusd/main"
mkdir -p "$APP_LOC" "$CONFIG_LOC" "$BIN_LOC" "$DESKTOP_LOC"

scripts=("focusd.sh" "run.sh" "stop.sh" "toggle.sh" "stats.sh")
for script in "${scripts[@]}"; do
	echo "Downloading $script..."
    	curl -sL "$REPO_URL/$script" -o "$APP_LOC/$script"

    	if [[ ! -s "$APP_LOC/$script" ]]; then
        	echo "${RED}Error: Failed to fetch ${YELLOW}$script${YELLOW} from GitHub.${RED}"
        	exit 1
    	fi
done

chmod +x "$APP_LOC"/*.sh

ln -sf "$APP_LOC/toggle.sh" "$BIN_LOC/focusd-toggle"
ln -sf "$APP_LOC/stats.sh" "$BIN_LOC/focusd-stats"

cat > "$BIN_LOC/focusd-config" <<EOF
#!/usr/bin/env bash
exec "$APP_LOC/focusd.sh" --config "\$@"
EOF
chmod +x "$BIN_LOC/focusd-config"

cat > "$DESKTOP_LOC/focusd.desktop" <<EOF
[Desktop Entry]
Name=Focusd (Study Mode)
Comment=Toggle Distraction-Free Study Mode
Exec=$APP_LOC/toggle.sh
Icon=utilities-terminal
Terminal=false
Type=Application
Categories=Utility;Education;
EOF

cat > "$DESKTOP_LOC/focusd-stats.desktop" <<EOF
[Desktop Entry]
Name=Focusd Statistics
Comment=View Study Mode Distraction Stats
Exec=$APP_LOC/stats.sh
Icon=utilities-system-monitor
Terminal=false
Type=Application
Categories=Utility;Education;
EOF

cat > "$DESKTOP_LOC/focusd-config.desktop" <<EOF
[Desktop Entry]
Name=Focusd Configuration
Comment=Reconfigure blocked apps and allowed websites
Exec=$APP_LOC/focusd.sh --config
Icon=preferences-system
Terminal=false
Type=Application
Categories=Utility;Settings;
EOF

chmod +x "$DESKTOP_LOC"/*.desktop

sudo -k
echo -e "${GREEN}Installation successful! Focusd is ready to use.${RESET}"
