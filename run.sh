temp="/tmp/temp.txt"
echo $$ > $temp
close() {
	[ -n "$child_pid" ] && kill "$child_pid" 2>/dev/null
	rm $temp
	exit 0
}

work_time=5400
break_time_before_notif=1080
notif_time=5280
break_time_after_notif=120
start_time=$(date +%s)
flag=false

trap close SIGTERM SIGINT
notify-send -a "Focusd" -u normal -t 3000 "Study Mode On" "Toggle the button to turn it off, break in 90 minutes"
APPS=("$@")
while true; do
	current_time=$(date +%s)
	elapsed_time=$((current_time - start_time))
	if [[ "$flag" == false && $elapsed_time -ge $notif_time && $elapsed_time -lt $work_time ]]; then
		notify-send -h boolean:transient:true -a "Focusd" -u normal -t 3500 "Break Time" "Break time starts in 2 minutes"
		flag=true
	elif [[ $elapsed_time -ge $work_time ]]; then
		notify-send -h boolean:transient:true -a "Focusd" -u normal -t 3000 "Break Time" "Restrictions removed for 20 minutes. Have a break!"
		sleep $break_time_before_notif & child_pid=$!
		wait $child_pid
		notify-send -h boolean:transient:true -a "Focusd" -u normal -t 3500 "Break Time" "Break time ends in 2 minutes"
		sleep $break_time_after_notif & child_pid=$!
		wait $child_pid
		notify-send -h boolean:transient:true -a "Focusd" -u normal -t 3000 "Study Mode On" "Restrictions applied, next break in 90 minutes"
		start_time=$(date +%s)
		flag=false
	fi
	for process in "${APPS[@]}"; do
		if pkill -f "$process"; then
			notify-send -h boolean:transient:true -a "Focusd" -u normal -t 3000 "Study Mode On" "Blocked $process to prevent distraction"
		fi
	done
	sleep 2 & child_pid=$!
	wait $child_pid
done
	
