temp="/tmp/temp.txt"
echo $$ > $temp
close() {
	echo "Deleting temp"
	rm $temp
	echo "Exiting"
	exit 0
}
trap close SIGTERM SIGINT
echo "Restricted Mode on"
APPS=("gedit" "gnome-calculator" "Discord")
while true; do
	for process in "${APPS[@]}"; do
		pid="$(pgrep -f "$process")"
		if [ -n "$pid" ]; then
			kill $pid
		fi
	done
	sleep 2 &
	wait $!
done
	
