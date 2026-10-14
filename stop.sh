file="/tmp/temp.txt"
if [[ ! -f "$file" ]]; then
	echo "Study mode is not running"
else
	pid=$(cat "$file")
	if kill -0 $pid 2>/dev/null; then
		kill -SIGTERM $pid
		echo "Study mode off"
	else
		rm -f "$file"
		echo "Unecessary temp removed"
	fi
fi
