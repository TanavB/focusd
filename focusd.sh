#!/usr/bin/env bash
config_dir="$HOME/.config/focusd"
config_file="$config_dir/blocked.conf"
website_file="$config_dir/allowed_sites.conf"
pid_loc="/tmp/focusd-$UID.txt"

if [[ -f "$pid_loc" ]]; then
        if kill -0 "$(<"$pid_loc")" 2>/dev/null && [[ "$1" != "--config" ]]; then
		notify-send -a "Focusd" -t 3000 "Study Mode On" "Study Mode is already running"
                exit 0
        fi
fi

mkdir -p "$config_dir"

show=false
if [[ "$1" == "--config" || ! -s "$config_file" || ! -s "$website_file" ]]; then
	show=true
fi

if [[ -f "$config_file" ]]; then
	readarray -t saved_apps < "$config_file"
fi

if [[ "$show" == true ]]; then
	display_apps=()

	for file in /usr/share/applications/*.desktop ~/.local/share/applications/*.desktop /var/lib/snapd/desktop/applications/*.desktop; do
		if [[ ! -f "$file" ]]; then
			continue
		fi

    		if ! grep -q "^Type=Application" "$file"; then
        		continue
    		fi

    		if grep -q "^NoDisplay=true" "$file"; then
        		continue
    		fi

   		if grep -q "^Hidden=true" "$file"; then
        		continue
    		fi
	
    		display_name=$(grep -m1 "^Name=" "$file" | cut -d'=' -f2-)
    		app_name=$(grep -m1 "^Exec=" "$file" | sed -E 's/^Exec=([^ ]+).*/\1/' | xargs -n1 basename 2>/dev/null)
    		if [[ -z "$display_name" || -z "$app_name" ]]; then
		    continue
    		fi
    		case "$app_name" in
	   		gnome-language-selector|nm-connection-editor|im-config|*info|firmware-updater|extension-manager|gnome-font-viewer|gnome-characters|gnome-power-statistics|software-properties*|gnome-session-properties|gnome-text-editor|gedit|gnome-disks|baobab|gnome-logs|file-roller|*system-monitor*|yelp|vim*|*terminal*|bash|sh|zsh|ptyxis|kitty|alacritty|nautilus|gnome-shell|mutter|gnome-control-center|gnome-tweaks|software-properties*|update-manager|ibus*|seahorse|system-config-printer|gnome-software|snap-store)
			continue ;;
    		esac

		status=FALSE
		for app in "${saved_apps[@]}"; do
			if [[ "$app" == "$app_name" ]]; then
				status=TRUE
				break
			fi
		done
    		display_apps+=("$status" "$display_name" "$app_name")
	done

	chosen=()

	while true; do
		chosen=$(zenity --list --checklist \
			--title="Select Distracting Apps" \
			--column="select" --column="Applications" --column="Exec Name" \
			--hide-column=3 --print-column=3 \
			--ok-label="Next" \
			--width=600 --height=550 \
			"${display_apps[@]}" 2>/dev/null)
		if [[ $? -ne 0 ]]; then
			exit 0
		fi
		if [[ -z "$chosen" ]]; then
			zenity --warning \
				--title="No selection" \
				--text="No apps selected, select distracting apps" 2>/dev/null
			continue
		fi
		
		echo "$chosen" | tr '|' '\n' > "$config_file"
		break
	done

	while true; do
		touch "$website_file"
		tmp_edit="/tmp/focusd_web_$UID.txt"
		cp "$website_file" "$tmp_edit"

		zenity --text-info --editable \
		--title="Allowed Websites" \
		--width=500 --height=450 \
		--filename "$website_file" > "$tmp_edit" 2>/dev/null

		if [[ $? -ne 0 ]]; then
			rm -f "$tmp_edit" 
			exit 0
		fi

		cat "$tmp_edit" | sed -E 's/^(https?:\/\/)?([^/]+).*/\2/' | tr '[:upper:]' '[:lower:]' | grep -v '^[[:space:]]*$' | sort -u > "$website_file"
		rm -f "$tmp_edit"
		break
	done
fi

if [[ -f "$pid_loc" ]]; then
        if kill -0 "$(<"$pid_loc")" 2>/dev/null; then
                kill -SIGHUP "$(<"$pid_loc")"
                exit 0
        else
                rm -f "$pid_loc"
        fi
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/run.sh" "init" > /dev/null 2>&1 &
