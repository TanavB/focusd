#!/usr/bin/env bash
config_dir="$HOME/.config/focusd"
log_file="$config_dir/session.log"

if [[ ! -s $log_file ]]; then
	zenity --info --title="Statistics" --text="Nothing to show here" --width=450 --height=450
else
	apps_blocked=$(grep -c "BLOCKED_APP" "$log_file")
	apps_blocked=${apps_blocked:-0}
	web_blocked=$(grep -c "BLOCKED_WEBSITE" "$log_file")
	web_blocked=${web_blocked:-0}
	distractions_blocked=$(( $apps_blocked + $web_blocked ))
	most_distracting_app=$(grep "BLOCKED_APP" "$log_file" | cut -d'|' -f 3- | sort | uniq -c | sort -nr | head -n 1 | sed -E 's/^[[:space:]]*[0-9]+[[:space:]](.*)/\1/')
	if [[ -z "$most_distracting_app" ]]; then
		most_distracting_app="None"
	fi
	most_distracting_web=$(grep "BLOCKED_WEBSITE" "$log_file" | cut -d'|' -f 3- | sort | uniq -c | sort -nr | head -n 1 | sed -E 's/^[[:space:]]*[0-9]+[[:space:]](.*)/\1/')
	if [[ -z "$most_distracting_web" ]]; then
		most_distracting_web="None"
	fi

	printf -v stats "Session Statistics\n\nTotal Distractions Blocked: $distractions_blocked\nTotal Apps Blocked: $apps_blocked\nTotal Websites Blocked: $web_blocked\nMost Distracting App: $most_distracting_app\nMost Distracting Website: $most_distracting_web"

	zenity --info --title="Statistics" --text="$stats" --width=450
fi
