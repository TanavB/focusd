file="/tmp/focusd-$UID.txt"
dnsmasq_file="/tmp/focusd-dns-$UID.txt"
if [[ ! -f "$file" ]]; then
	notify-send -a "Focusd" -u normal "Study Mode Toggle" "Study mode is not running"
else
	pid=$(cat "$file")
	if kill -0 $pid 2>/dev/null; then
		kill -SIGTERM $pid
		notify-send -a "Focusd" -u normal "Study Mode Off" "Study mode has been turned off"
	else
		rm -f "$file"
		notify-send -a "Focusd" -u low "Study Mode Toggle" "Cleaned up temp file"
	fi
fi

if [[ -f "$dnsmasq_file" ]]; then
	pid=$(cat "$dnsmasq_file")
	if sudo kill -0 $pid 2>/dev/null; then
		sudo kill $pid
	else 
		rm -f "$dnsmasq_file"
	fi
fi
