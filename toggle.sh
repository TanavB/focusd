#!/usr/bin/env bash
pid_file="/tmp/focusd-$UID.txt"

if [[ -f "$pid_file" ]] && kill -0 "$(<"$pid_file")" 2>/dev/null; then
    "/home/tanav-bhatter/Desktop/Study Mode/stop.sh"
else
    "/home/tanav-bhatter/Desktop/Study Mode/focusd.sh"
fi
