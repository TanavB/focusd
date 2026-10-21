#!/usr/bin/env bash
pid_file="/tmp/focusd-$UID.txt"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$pid_file" ]] && kill -0 "$(<"$pid_file")" 2>/dev/null; then
	"$script_dir/stop.sh"
else
	"$script_dir/focusd.sh"
fi
