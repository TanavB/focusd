#!/usr/bin/env bash

file="/tmp/focusd-$UID.txt"
dnsmasq_file="/tmp/focusd-dns-$UID.txt"
dns_raw_log="$HOME/.config/focusd/dns-raw.log"
allow_config_file="$HOME/.config/focusd/dnsmasq_sites.conf"
web_config_file="$HOME/.config/focusd/allowed_sites.conf"
if [[ ! -f "$file" ]]; then
	if [[ -f "$dnsmasq_file" ]]; then
		sudo kill "$(cat "$dnsmasq_file")" 2>/dev/null
		rm -f "$dnsmasq_file"
	fi
	rm -f "$dns_raw_log"
	notify-send -a "Focusd" -u normal "Study Mode Toggle" "Study mode is not running"
else
	settings_file="$HOME/.config/focusd/settings.conf"
	if [[ -f "$settings_file" ]]; then
		source "$settings_file"
	fi
	pid=$(cat "$file")
	if kill -0 "$pid" 2>/dev/null; then	
		injected=false
		if ! grep -q "codeforces.com" "$allow_config_file"; then
			injected=true
			echo "server=/codeforces.com/8.8.8.8" >> "$allow_config_file"
			echo "server=/codeforces.org/8.8.8.8" >> "$allow_config_file"
			if [[ -f "$dnsmasq_file" ]]; then
				sudo kill -HUP "$(cat "$dnsmasq_file")" 2>/dev/null
			fi
			sudo resolvectl flush-caches 2>/dev/null
			sleep 0.5
		fi

		problemset=$(curl -s "https://codeforces.com/api/problemset.problems" | jq -r '.result.problems | map(select(.rating >= 800 and .rating <= 900)) | .[range(length)] | "\(.contestId)|\(.index)|\(.name)"')

		if [[ -z "$problemset" ]]; then
			zenity --warning --title="Hardcore Challenge Error" --text="Cannot reach Codeforces, skipping challenge" --width=450 2>/dev/null
		else
			solved=false
			while [[ "$solved" == false ]]; do
				problem=$(echo "$problemset" | shuf -n 1)
				contest_id=$(echo "$problem" | cut -d'|' -f1)
				index=$(echo "$problem" | cut -d'|' -f2)
				problem_name=$(echo "$problem" | cut -d'|' -f3)
				xdg-open "https://codeforces.com/contest/$contest_id/problem/$index" > /dev/null 2>&1 &

				while true; do
					handle=$(zenity --entry \
						--title="Hardcore Challenge" \
						--text="Solve Problem: $index - $problem_name and enter your CF handle below" \
						--entry-text="${cf_handle:-}" \
						--extra-button="Reroll Problem" \
						--ok-label="Verify" \
						--width=450 2>/dev/null)
					exit_stat=$?
					if [[ "$handle" == "Reroll Problem" ]]; then
						break
					fi
					if [[ $exit_stat -ne 0 || -z "$handle" ]]; then
						if [[ "$injected" == true ]]; then
							sed -i '/codeforces/d' "$allow_config_file"
							if [[ -f "$dnsmasq_file" ]]; then
								sudo kill -HUP "$(cat "$dnsmasq_file")" 2>/dev/null
							fi
							sudo resolvectl flush-caches 2>/dev/null
						fi
						notify-send -a "Focusd" -u critical "Challenge Incomplete" "Study mode remains active."
						exit 1
					fi

					verdict=$(curl -s "https://codeforces.com/api/user.status?handle=$handle&from=1&count=5" | jq -r --arg cid "$contest_id" --arg idx "$index" '.result[]? | select((.problem.contestId|tostring) == $cid and .problem.index == $idx and .verdict == "OK") | .verdict' | head -n 1)
					if [[ "$verdict" == "OK" ]]; then
						zenity --info --title="Hardcore Challenge" --text="Problem solved! Study mode will now stop" --width=450 2>/dev/null
						if grep -q "^cf_handle=" "$settings_file" 2>/dev/null; then
							sed -i "s/^cf_handle=.*/cf_handle=\"$handle\"/" "$settings_file"
						else
							echo "cf_handle=\"$handle\"" >> "$settings_file"
						fi
						solved=true
						break
					else
						zenity --info --title="Hardcore Challenge" --text="No corresponding submission found, try again" --width=450 2>/dev/null
					fi
					cf_handle="$handle"				
				done
			done
		fi

		kill -SIGTERM "$pid"
		while kill -0 "$pid" 2>/dev/null; do
			sleep 0.1
		done
		notify-send -a "Focusd" -u normal "Study Mode Off" "Study mode has been turned off"
	else
		rm -f "$file"
		if [[ -f "$dnsmasq_file" ]]; then
			sudo kill "$(cat "$dnsmasq_file")" 2>/dev/null
			rm -f "$dnsmasq_file"
		fi
		rm -f "$dns_raw_log"
		notify-send -a "Focusd" -u low "Study Mode Toggle" "Cleaned up temp file"
	fi
fi
