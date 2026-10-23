#!/usr/bin/env bash
config_dir="$HOME/.config/focusd"
config_file="$config_dir/blocked.conf"
website_file="$config_dir/allowed_sites.conf"
settings_file="$config_dir/settings.conf"
pid_loc="/tmp/focusd-$UID.txt"

if [[ -f "$pid_loc" ]]; then
        if kill -0 "$(<"$pid_loc")" 2>/dev/null && [[ "$1" != "--config" ]]; then
		notify-send -a "Focusd" -t 3000 "Study Mode On" "Study Mode is already running"
                exit 0
        fi
fi

mkdir -p "$config_dir"

show=false
if [[ "$1" == "--config" || ! -s "$config_file" || ! -s "$website_file" || ! -s "$settings_file" ]]; then
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
	
	touch "$settings_file"
	if [[ -s "$settings_file" ]]; then
		source "$settings_file" 2>/dev/null
	fi
	default_work_min=$(( ${work_time:-5400} / 60 ))

	zenity --question \
		--title="Hardcore Mode" \
		--text="Enable Hardcore Mode?\n(Requires solving a Codeforces problem to exit Study Mode early)" \
		--width=450 2>/dev/null

	if [[ $? -eq 0 ]]; then
		hardcore_mode="true"
		cf_handle=$(zenity --entry \
			--title="Codeforces Handle" \
			--text="Enter your Codeforces handle for verification challenges:" \
			--entry-text="${cf_handle:-}" \
			--width=450 2>/dev/null)

		if [[ $? -ne 0 ]]; then
			if [[ ! -s "$settings_file" ]]; then
				rm -f "$settings_file"
			fi
			exit 0
		fi
	else
		hardcore_mode="false"
		cf_handle="${cf_handle:-}" # Keep previous handle in config just in case
	fi

	touch "$settings_file"
	work_time=$(zenity --scale \
			--text="Select working time in minutes" \
			--min-value=30 \
			--max-value=120 \
			--value="$default_work_min" \
			--step=5 2>/dev/null)

	if [[ $? -ne 0 ]]; then
		if [[ ! -s "$settings_file" ]]; then
			rm -f "$settings_file"
		fi
		exit 0
	fi
	work_time=$(( ((work_time + 2) / 5) * 5 ))
	max_break=$(( work_time - 5 ))
	last_break_min=$(( ${break_time:-1200} / 60 ))
	if [[ $last_break_min -le $max_break && $last_break_min -ge 5 ]]; then
		default_break=$last_break_min
	else
		default_break=20
	fi	
	break_time=$(zenity --scale \
			--text="Select break time in minutes" \
			--min-value=5 \
			--max-value=$max_break \
			--value=$default_break \
			--step=5 2>/dev/null)
	
	if [[ $? -ne 0 ]]; then
		if [[ ! -s "$settings_file" ]]; then
			rm -f "$settings_file"
		fi
		exit 0
	fi
	break_time=$(( ((break_time + 2) / 5) * 5 ))
	
	echo "hardcore_mode=\"$hardcore_mode\"" > "$settings_file"
	echo "cf_handle=\"$cf_handle\"" >> "$settings_file"
	echo "work_time=$(( work_time * 60 ))" >> "$settings_file"
	echo "break_time=$(( break_time * 60 ))" >> "$settings_file"
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
