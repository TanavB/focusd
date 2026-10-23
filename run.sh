#!/usr/bin/env bash
temp="/tmp/focusd-$UID.txt"
dns_raw_log="/tmp/focusd-dns-raw-$UID.log"
echo $$ > "$temp"

clear_firewall(){
	
	while sudo iptables -D OUTPUT -p udp --dport 443 -j REJECT 2>/dev/null; do :; done
	while sudo ip6tables -D OUTPUT -p tcp -m multiport --dports 80,53,443 -j REJECT; do :; done
	while sudo ip6tables -D OUTPUT -p udp -m multiport --dports 80,53,443 -j REJECT; do :; done
	
	DOH_IPS=(
    		"8.8.8.8" "8.8.4.4"           # Google
    		"1.1.1.1" "1.0.0.1"           # Cloudflare
    		"9.9.9.9" "149.112.112.112"   # Quad9
    		"94.140.14.14" "94.140.15.15" # AdGuard
    		"208.67.222.222" "208.67.220.220" # OpenDNS
    		"45.90.28.0" "45.90.30.0"     # NextDNS
    		"185.228.168.9" "185.228.169.9" # CleanBrowsing
    		"76.76.2.0" "76.76.10.0"      # Control D
    		"194.242.2.2" "194.242.2.3"   # Mullvad
    		"77.88.8.8" "77.88.8.1"       # Yandex
	)
	for ip in "${DOH_IPS[@]}"; do
    		while sudo iptables -D OUTPUT -p tcp -d "$ip" -m multiport --dports 80,443 -j REJECT; do :; done
		while sudo iptables -D OUTPUT -p udp -d "$ip" -m multiport --dports 80,443 -j REJECT; do :; done
	done

	while sudo iptables -D OUTPUT -t nat -p tcp --dport 53 -j DNAT -m owner --uid-owner $UID --to-destination 127.0.0.1:5354; do :; done
	while sudo iptables -D OUTPUT -t nat -p udp --dport 53 -j DNAT -m owner --uid-owner $UID --to-destination 127.0.0.1:5354; do :; done
	sudo resolvectl flush-caches 2>/dev/null
	sudo conntrack -F
	sudo ss -K -t state established '( dport = :http or dport = :https or sport = :http or sport = :https )' 2>/dev/null
}

apply_firewall(){
        clear_firewall
	
	sudo sysctl -w net.ipv4.conf.all.route_localnet=1 >/dev/null 2>&1
	sudo iptables -I OUTPUT 1 -p udp --dport 443 -j REJECT
	sudo ip6tables -I OUTPUT 1 -p tcp -m multiport --dports 80,53,443 -j REJECT
	sudo ip6tables -I OUTPUT 1 -p udp -m multiport --dports 80,53,443 -j REJECT
	
	DOH_IPS=(
    		"8.8.8.8" "8.8.4.4"           # Google
    		"1.1.1.1" "1.0.0.1"           # Cloudflare
    		"9.9.9.9" "149.112.112.112"   # Quad9
    		"94.140.14.14" "94.140.15.15" # AdGuard
    		"208.67.222.222" "208.67.220.220" # OpenDNS
    		"45.90.28.0" "45.90.30.0"     # NextDNS
    		"185.228.168.9" "185.228.169.9" # CleanBrowsing
    		"76.76.2.0" "76.76.10.0"      # Control D
    		"194.242.2.2" "194.242.2.3"   # Mullvad
    		"77.88.8.8" "77.88.8.1"       # Yandex
	)
	for ip in "${DOH_IPS[@]}"; do
    		sudo iptables -A OUTPUT -p tcp -d "$ip" -m multiport --dports 80,443 -j REJECT
		sudo iptables -A OUTPUT -p udp -d "$ip" -m multiport --dports 80,443 -j REJECT
	done
	
	sudo iptables -I OUTPUT 1 -t nat -p tcp --dport 53 -j DNAT -m owner --uid-owner $UID --to-destination 127.0.0.1:5354
	sudo iptables -I OUTPUT 1 -t nat -p udp --dport 53 -j DNAT -m owner --uid-owner $UID --to-destination 127.0.0.1:5354
	sudo resolvectl flush-caches 2>/dev/null
	sudo conntrack -F 2>/dev/null
	sudo ss -K -t state established '( dport = :http or dport = :https or sport = :http or sport = :https )' 2>/dev/null
}

close() {
	clear_firewall
	if [[ -f "/tmp/focusd-dns-$UID.txt" ]]; then
		sudo kill "$(cat "/tmp/focusd-dns-$UID.txt")" 2>/dev/null
	fi
	if [[ -n "$child_pid" ]]; then
		kill "$child_pid" 2>/dev/null
	fi
	if [[ -n "$dns_tail_pid" ]]; then
    		kill "$dns_tail_pid" 2>/dev/null
	fi
	rm -f "/tmp/focusd-dns-$UID.txt"
	rm -f "$dns_raw_log"
	rm -f "$temp"
	exit 0
}

config_dir="$HOME/.config/focusd"
config_file="$config_dir/blocked.conf"
web_config_file="$config_dir/allowed_sites.conf"
allow_config_file="$config_dir/dnsmasq_sites.conf"
settings_file="$config_dir/settings.conf"
load_settings() {
	if [[ -f "$settings_file" ]]; then
		source "$settings_file"
	else
		work_time=5400      # 90 mins
		break_time=1200     # 20 mins
	fi

	# Break notification alert logic (warning 2 mins / 120s prior)
	notif_time=$(( work_time - 120 ))

	# Partition break sleep: stage 1 before warning, stage 2 (120s) after warning
	break_time_before_notif=$(( break_time - 120 ))
	break_time_after_notif=120
}
log_file="$config_dir/session.log"
log_event() {
    local event_type="$1"
    local payload="$2"
    printf "%s|%s|%s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$event_type" "$payload" >> "$log_file"
}

rewrite(){
	load_settings
	readarray -t APPS < "$config_file"
	readarray -t WEBSITES < "$web_config_file"
	echo "address=/#/0.0.0.0" > "$allow_config_file"
	echo "address=/use-application-dns.net/0.0.0.0" >> "$allow_config_file"
	for website in "${WEBSITES[@]}"; do
		if [[ -z "$website" || "$website" =~ ^[[:space:]]*# ]]; then
			continue
		fi
		echo "server=/$website/8.8.8.8" >> "$allow_config_file"
	done
	CORE_INFRA=(
		"cloudflare.com"
		"cdnjs.cloudflare.com"
		"fastly.net"
		"cloudfront.net"
		"akamaihd.net"
		"edgekey.net"
		"jsdelivr.net"
		"unpkg.com"
		"bootstrapcdn.com"
		"code.jquery.com"
		"gstatic.com"
		"googleapis.com"
		"googleusercontent.com"
		"accounts.google.com"
		"recaptcha.net"
		"hcaptcha.com"
		"githubassets.com"
		"githubusercontent.com"
		"sstatic.net"
		"wikimedia.org"
		"redditstatic.com"
		"redditmedia.com"
		"redd.it"
		"notion-static.com"
		"msgapp.com"
		"licdn.com"
		"visualstudio.com"
		"vscode-unpkg.net"
		"figma.net"
	)
	
	for cdn in "${CORE_INFRA[@]}"; do
		echo "server=/$cdn/8.8.8.8" >> "$allow_config_file"
	done
	echo "local-ttl=0" >> "$allow_config_file"
	echo "log-queries" >> "$allow_config_file"
	echo "log-facility=$dns_raw_log" >> "$allow_config_file"
	if [[ -f "/tmp/focusd-dns-$UID.txt" ]]; then
		sudo kill "$(cat "/tmp/focusd-dns-$UID.txt")"
	fi

	sudo dnsmasq -C "$allow_config_file" -a 127.0.0.1 -p 5354 -x "/tmp/focusd-dns-$UID.txt"
	apply_firewall

	if [[ "$1" != "init" ]]; then
		notify-send -a "Focusd" -u low -t 2000 "Study Mode On" "Distracting Apps Updated"
		log_event "START" "WORK_TIME=$work_time"
	fi
}


load_settings
start_time=$(date +%s)
flag=false
pre_released=false

trap close SIGTERM SIGINT
trap rewrite SIGHUP
notify-send -a "Focusd" -u normal -t 3000 "Study Mode On" "Toggle button to turn off. Next break in $(( work_time / 60 )) minutes."
rewrite init
touch "$dns_raw_log"
tail -F -n0 "$dns_raw_log" 2>/dev/null | while read -r _ _ _ _ _ event domain _ ip; do
    if [[ "$ip" == "0.0.0.0" && "$domain" != "use-application-dns.net" ]]; then
        printf "%(%Y-%m-%d %H:%M:%S)T|BLOCKED_WEBSITE|%s\n" -1 "$domain" >> "$log_file"
    fi
done &
dns_tail_pid=$!
while true; do
	current_time=$(date +%s)
	elapsed_time=$((current_time - start_time))
	if [[ "$flag" == false && $elapsed_time -ge $notif_time && $elapsed_time -lt $work_time ]]; then
		notify-send -h boolean:transient:true -a "Focusd" -u normal -t 3500 "Break Time" "Break time starts in 2 minutes"
		flag=true
	elif [[ "$pre_released" == false && $elapsed_time -ge $((work_time - 60)) ]]; then
		clear_firewall
		pre_released=true
	elif [[ $elapsed_time -ge $work_time ]]; then
		notify-send -h boolean:transient:true -a "Focusd" -u normal -t 3000 "Break Time" "Restrictions removed for $(( break_time / 60 )) minutes. Have a break!"
		log_event "BREAK_START" "BREAK_TIME=$break_time"
		sleep $break_time_before_notif & child_pid=$!
		wait $child_pid
		notify-send -h boolean:transient:true -a "Focusd" -u normal -t 3500 "Break Time" "Break time ends in 2 minutes"
		sleep $break_time_after_notif & child_pid=$!
		wait $child_pid
		notify-send -h boolean:transient:true -a "Focusd" -u normal -t 3000 "Study Mode On" "Restrictions applied, next break in $(( work_time / 60 )) minutes"
		apply_firewall
		start_time=$(date +%s)
		flag=false
		pre_released=false
	fi
	for process in "${APPS[@]}"; do
		if [[ -z "$process" ]]; then continue; fi
		if { [[ ${#process} -le 15 ]] && pkill -x -i "$process"; } || { [[ ${#process} -gt 15 ]] && pkill -f -i "(^|/)$process($| )"; }; then
			notify-send -h boolean:transient:true -a "Focusd" -u normal -t 3000 "Study Mode On" "Blocked $process to prevent distraction"
			log_event "BLOCKED_APP" "$process"
		fi
	done

	sleep 2 & child_pid=$!
	wait $child_pid
done
	
