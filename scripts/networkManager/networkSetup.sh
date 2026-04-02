#!/bin/bash

#Text variables
BOLD=$'\e[1m'
RESET=$'\e[0m'
ACCENT=$'\e[96m'
RED=$'\e[31m'
GREEN=$'\e[32m'

#ethernet, wifi, loopback, vlan, bridge, bond, team, tun/tap, vpn
function setup-ethernet-profile() {
	ACTIVE=$(nmcli connection show | sed -n "/${INTERFACES[$i]}/ p")
	if [[ -z $ACTIVE ]]; then
		nmcli connection add type ethernet ifname ${INTERFACES[$i]} con-name ${INTERFACES[$i]}
	fi
}

function setup-vlan-profile() {
	echo -e "${BOLD}Enter VLAN id (Number): ${RESET}"
	read VLANID
	echo -e "${BOLD}Enter VLAN ip address (xxx.xxx.xxx.xxx/xx): ${RESET}"
	read IP
	echo -e "${BOLD}Enter VLAN gateway (Press ENTER to skip): ${RESET}"
	read GW
	echo -e "${BOLD}Enter VLAN DNS (Press ENTER to skip): ${RESET}"
	read DNS

	if [[ -n $GW ]]; then
		nmcli connection add type vlan con-name "VLAN${VLANID}" dev ${INTERFACES[$i]} id $VLANID ip4 $IP gw4 $GW	
	else
		nmcli connection add type vlan con-name "VLAN${VLANID}" dev ${INTERFACES[$i]} id $VLANID ip4 $IP
	fi

	if [[ -n $DNS ]]; then
		nmcli connection modify "VLAN${VLANID}" ipv4.dns $DNS
	fi
	
	INTERFACES[$i]="VLAN${VLANID}"
	unset VLANID
	unset IP
	unset GW
	unset DNS
}

function setup-bonded-profile() {
	echo -e "${BOLD}Enter bond name: ${RESET}"
	read NAME
	echo "Bond modes: balance-rr, active-backup, 802.3ad, balance-xor, broadcast, balance-tlb, balance-alb"
	echo -e "${BOLD}Enter the mode of the bond: ${RESET}"
	read MODE
	echo -e "${BOLD}Enter the number of slaves for this bond: ${RESET}"
	read SLAVES

	nmcli connection add type bond con-name $NAME ifname $NAME mode $MODE
	nmcli connection add type bond-slave con-name $NAME-slave$NUM ifname ${INTERFACES[$i]} master $NAME

	INTERFACES[$i]=$NAME
	unset NAME
	unset MODE
}

function addto-bonded-profile() {
	echo -e "${BOLD}Enter bond name: ${RESET}"
	read NAME
	nmcli connection add type bond-slave con-name $NAME-slave$NUM ifname ${INTERFACES[$i]} master $NAME
	INTERFACES[$i]=$NAME
	unset NAME
}

function addto-teamed-profile() {
	echo -e "${BOLD}Enter team name: ${RESET}"
	read NAME
	nmcli connection add type team-slave con-name $NAME-slave$NUM ifname ${INTERFACES[$i]} master $NAME
	INTERFACES[$i]=$NAME
	unset NAME
}

function setup-teamed-profile() {
	echo -e "${BOLD}Enter team name: ${RESET}"
	read NAME
	echo "Team runners: active-backup, lcap (802.3ad), loadbalance, roundrobin"
	echo -e "${BOLD}Enter the runner for this team: ${RESET}"
	read MODE
	echo -e "${BOLD}Enter the number of slaves for this team: ${RESET}"
	read SLAVES

	nmcli connection add type bond con-name $NAME ifname $NAME config '{"runner":{"name": "$MODE"}}'
	nmcli connection add type bond-slave con-name $NAME-slave$NUM ifname ${INTERFACES[$i]} master $NAME

	INTERFACES[$i]=$NAME
	unset NAME
	unset MODE
}

function setup-bridge-profile() {
	echo -e "${BOLD}Enter bridge name: ${RESET}"
	read NAME
	nmcli connection add type bridge con-name $NAME ifname $NAME
	nmcli connection add type bridge-slave ifname ${INTERFACES[$i]} master $NAME
	INTERFACES[$i]=$NAME
	unset NAME
}

function remove-profile() {
	nmcli
	echo ""
	echo -e "${BOLD}Enter interface to remove: ${RESET}"
	read NIC
	#nmcli connection del type ethernet ifname $NIC con-name $NIC
	nmcli connection delete $NIC
	menu
}

function query-method() {
	echo -e "${BOLD}Enter ipv4 method (static ; auto): ${RESET}"
	read METHOD
}

function setup-method() {
	if [[ $METHOD == "static" || $METHOD == "auto" ]]; then
		nmcli connection modify ${INTERFACES[$i]} ipv4.method $METHOD
		unset METHOD
	fi
}

function setup-address() {
	echo -e "${BOLD}Enter ipv4 address/mask (ENTER to skip): ${RESET}"
	read ADDRESS
	if [[ -n $ADDRESS ]]; then
		nmcli connection modify ${INTERFACES[$i]} ipv4.address $ADDRESS
		unset ADDRESS
	fi	
}

function setup-gateway() {
	echo -e "${BOLD}Enter default gateway (ENTER to skip): ${RESET}"
	read GATEWAY
	if [[ -n $GATEWAY ]]; then
		nmcli connection modify ${INTERFACES[$i]} ipv4.address $GATEWAY
		unset GATEWAY
	fi	
}

function setup-dns() {
	echo -e "${BOLD}Enter dns address (Comma separated list) (ENTER to skip): ${RESET}"
	read DNS
	if [[ -n $DNS ]]; then
		nmcli connection modify ${INTERFACES[$i]} ipv4.dns $DNS
		unset DNS
	fi	
}

function append-dns() {
	CURRENT=$(nmcli -g ipv4.dns connection show ${INTERFACES[$i]})
	echo -e "${BOLD}Current dns servers: ${RESET}\n$CURRENT"
	echo ""
	echo -e "${BOLD}Enter dns address (Comma separated list) (ENTER to skip): ${RESET}"
	read DNS
	if [[ -n $DNS ]]; then
		nmcli connection modify ${INTERFACES[$i]} ipv4.dns "${CURRENT},${DNS}"
		unset DNS
	fi	
	unset CURRENT
}

function activate-interface(){
	nmcli connection up ${INTERFACES[$i]}
}

function change-device-name(){
	echo -e "${BOLD}Enter the new name for this device (ENTER to skip): ${RESET}"
	read NAME
	if [[ -n $NAME ]]; then
		nmcli connection modify ${INTERFACES[$i]} con-name $NAME
	fi
	INTERFACES[$i]=$NAME
	unset NAME
}

function get-info() {
	mapfile -t INTERFACES < <(nmcli | grep connected | gawk -F" " '$4 != "lo" && $4 != "to" && NF >= 4 { print $4 }')
	mapfile -t -O "${#INTERFACES[@]}" INTERFACES < <(nmcli | grep disconnected | gawk -F":" '$1 != "lo" { print $1 }')
	mapfile -t ADDRESSES < <(nmcli | grep inet4 | gawk -F" " '$2 != "127.0.0.1/8" { print $2 }' | gawk -F"/" '{ print $1 }')
	mapfile -t MASKS < <(nmcli | grep inet4 | gawk -F" " '$2 != "127.0.0.1/8" { print $2 }' | gawk -F"/" '{ print $2 }')
	echo ""
	echo -e "${BOLD}Connected interfaces: ${RESET}"
	# Display
	for i in "${!INTERFACES[@]}"; do
		echo "${i}) ${INTERFACES[$i]} : ${ADDRESSES[$i]}/${MASKS[$i]}"
	done
	echo ""
}

function action-sequence1() {
	setup-ethernet-profile
	query-method
	if [[ $METHOD == "static" ]]; then
		setup-address
		setup-gateway
		setup-dns
		setup-method
	elif [[ $METHOD == "auto" ]]; then
		setup-method
	fi
	activate-interface
	get-info
}

function action-sequence1-1() {
	query-method
	if [[ $METHOD == "static" ]]; then
		setup-address
		setup-gateway
		setup-dns
		setup-method
	elif [[ $METHOD == "auto" ]]; then
		setup-method
	fi
	activate-interface
	get-info
}

function action-sequence2() {
	append-dns
}

function action-sequence3() {
	setup-vlan-profile
	activate-interface
	get-info
}

function action-sequence4() {
	change-device-name
	activate-interface
	get-info
}

function action-sequence5() {
	NUM=1
	setup-bonded-profile
	action-sequence1-1
	for NUM in $(seq 2 $SLAVES); do
		process addto-bonded-profile
	done
	unset NUM
}

function action-sequence6() {
	NUM=1
	setup-teamed-profile
	action-sequence1-1
	for NUM in $(seq 2 $SLAVES); do
		process addto-teamed-profile
	done
	unset NUM
}

function action-sequence7() {
	setup-bridge-profile
	action-sequence1-1
}

function process() {
	get-info
	echo -e "${BOLD}Select an interface to modify: ${RESET}"
	read CHOICE
	for i in "${!INTERFACES[@]}"; do
		if [ "$i" -eq "$CHOICE" ]; then
			# Run parameter function $1
			$1
		fi
	done
	echo -e "${BOLD}Press ENTER to continue${RESET}"
	read VOID
	menu
}

function menu() {
	clear
	echo -e "${BOLD}	Network Manager	${RESET}"
	cat << EOF
0) Display interfaces
1) Change device name
2) Setup networking for an interface
3) Append DNS server
4) Remove profile (Delete interface configuration)
5) Setup VLAN on interface
6) Setup bonded interfaces
7) Setup teamed interfaces
8) Setup bridged interface

Q) Quit	
EOF
	echo -e "${BOLD}Choose an action from the menu: ${RESET}"
	read INPUT
	case $INPUT in
		0) clear;get-info;echo -e "${BOLD}Press ENTER to continue${RESET}";read VOID;menu;;
		1) clear;process action-sequence4; unset INPUT;;
		2) clear;process action-sequence1; unset INPUT;;
		3) clear;process action-sequence2; unset INPUT;;
		4) clear;remove-profile;;
		5) clear;process action-sequence3; unset INPUT;;
		6) clear;process action-sequence5; unset INPUT;;
		7) clear;process action-sequence6; unset INPUT;;
		8) clear;process action-sequence7; unset INPUT;;
		[qQ]) exit;;
	esac
}

menu
