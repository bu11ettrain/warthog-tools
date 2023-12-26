#!/bin/bash

GITHUB_URL="https://api.github.com/repos/warthog-network/Warthog/releases/latest"
NODE_NAME=wart-node-linux
WALLET_NAME=wart-wallet-linux
SCREEN_NAME=wart_node
WORK_DIR="${PWD}/wart-node"
LOCAL_IP=`ip route get 1 | awk '{print $(NF-2);exit}'`
PUBLIC_IP=`wget -q -O - ipinfo.io/ip`
DISTRIB_NAME=`grep DISTRIB_ID /etc/*-release | awk -F '=' '{print $2}'`

function install() {
	echo -e "\nChecking dependencies ..."
	if [ "$DISTRIB_NAME" == "Ubuntu" ]; then
		pkgs='jq screen'
		install=false
		for pkg in $pkgs; do
		  status="$(dpkg-query -W --showformat='${db:Status-Status}' "$pkg" 2>&1)"
		  if [ ! $? = 0 ] || [ ! "$status" = installed ]; then
		    install=true
		    break
		  fi
		done
		if "$install"; then
		  sudo apt install -y $pkgs > /dev/null 2>&1
		fi
	fi		

	if [ -d "$WORK_DIR" ]; then
		if [ -f "$WORK_DIR/$NODE_NAME" ]; then
			echo Removing $NODE_NAME ...
			rm $WORK_DIR/$NODE_NAME
		fi
		if [ -f "$WORK_DIR/$WALLET_NAME" ]; then
			echo Removing $WALLET_NAME ...
			rm $WORK_DIR/$WALLET_NAME
		fi
	else
		echo Creating $WORK_DIR ...
		mkdir -p $WORK_DIR
	fi

	echo Downloading the latest releases of $NODE_NAME and $WALLET_NAME ...
	url=$(curl -s $GITHUB_URL | jq -r ".assets[] | select(.name | test(\"$NODE_NAME\")) | .browser_download_url"); wget -q --show-progress "$url" -P $WORK_DIR
	url=$(curl -s $GITHUB_URL | jq -r ".assets[] | select(.name | test(\"$WALLET_NAME\")) | .browser_download_url"); wget -q --show-progress "$url" -P $WORK_DIR
	chmod +x $WORK_DIR/$NODE_NAME
	chmod +x $WORK_DIR/$WALLET_NAME
	if [ -f "$WORK_DIR/$NODE_NAME" ] && [ -f "$WORK_DIR/$WALLET_NAME" ]; then
		echo -e "\033[1;35m$NODE_NAME\033[0m and \033[1;35m$WALLET_NAME\033[0m have been installed into \033[0;36m$WORK_DIR\033[0m"
	else
		echo -e "\n\033[0;31mOpps! Something went wrong.\033[0m"
	fi
}

function start() {
	if [ -d "$WORK_DIR" ]; then
		if [ -f "$WORK_DIR/$NODE_NAME" ]; then
			echo -e "\nStarting $NODE_NAME ..."
			screen -dmS $SCREEN_NAME bash -c "while true; do $WORK_DIR/$NODE_NAME --rpc=0.0.0.0:3000 ; done"
			SCREEN_PID=`screen -ls $SCREEN_NAME | grep -Po "\K[0-9]+(?=\.$SCREEN_NAME)"`
			if [[ ! -z $SCREEN_PID ]]; then
				echo -e "Screen session \033[1;32m$SCREEN_NAME\033[0m with \033[0;36m$WORK_DIR/$NODE_NAME --rpc=0.0.0.0:3000\033[0m has been launched."
				echo -e "Use \033[1;33mscreen -r $SCREEN_NAME\033[0m to see its output and CTRL+A+D to detach from the screen session."
				echo -e "Use \033[1;31mscreen -XS $SCREEN_NAME quit\033[0m to close a session."
			else
				echo -e "\n\033[0;31mOpps! Something went wrong.\033[0m"
			fi
		else
			echo -e "\n\033[0;31mYou should install Warthog node first.\033[0m"
		fi
	else
		echo -e "\n\033[0;31mYou should install Warthog node first.\033[0m"
	fi
}

function shutdown() {
	echo -e "\nShutting down $NODE_NAME ..."
	SCREENS=`screen -ls $SCREEN_NAME | grep -Po "\K[0-9]+(?=\.$SCREEN_NAME)"`
	if [[ ! -z $SCREENS ]]; then
		for pid in $SCREENS; do
	#		echo Killing screen $pid.$SCREEN_NAME
			screen -S $pid.$SCREEN_NAME -X quit
		done
	fi
	kill $(ps aux | grep $NODE_NAME | awk '{print $2}') > /dev/null 2>&1
	echo Done!
}

function get_ip() {
		echo -e "\nYour node local IP: \033[1;35m$LOCAL_IP\033[0m"
		echo -e "Your node public IP: \033[1;35m$PUBLIC_IP\033[0m"
}

function wipe() {
	echo -e "\nRemoving .warthog ..."
	if [  -n "$(uname -a | grep hiveos)" ]; then
		if [ -d "/root/.warthog" ]; then
			rm -r /root/.warthog
			echo Directory /root/.warthog has been removed
		fi
	else
		if [ -d "${PWD}/.warthog" ]; then
			rm -r ${PWD}/.warthog
			echo Directory ${PWD}/.warthog has been removed
		fi
	fi	 
}

function show_screen() {
	SCREEN_PID=`screen -ls $SCREEN_NAME | grep -Po "\K[0-9]+(?=\.$SCREEN_NAME)"`
	if [[ ! -z $SCREEN_PID ]]; then
		screen -r $SCREEN_NAME
	else
		echo -e "\n\033[0;31mYou should start Warthog node first.\033[0m"
	fi
}

echo -ne "
\033[1;33m
 __      ___   ___ _____ _  _  ___   ___   _  _  ___  ___  ___ 
 \ \    / /_\ | _ |_   _| || |/ _ \ / __| | \| |/ _ \|   \| __|
  \ \/\/ / _ \|   / | | | __ | (_) | (_ | |    | (_) | |) | _| 
   \_/\_/_/ \_|_|_\ |_| |_||_|\___/ \___| |_|\_|\___/|___/|___|
							MANAGER                                 
\033[0;36m
1) Install or Update Warthog node
2) Remove local blockchain data (.warthog) and resync Warthog node
3) Start Warthog Node
4) Stop Warthog Node
5) Show your Warthog node LOCAL and PUBLIC IP
6) Show Warthog node output (Use CTRL+A+D to detach from the screen session)
0) Exit menu \n\033[0m"  
read -rp "Pick an option and hit ENTER: "	
case "$REPLY" in
	1) shutdown; install; start; get_ip;;
	2) shutdown; wipe; start; get_ip;;
	3) start; get_ip;;
	4) shutdown;;
	5) get_ip;;
	6) show_screen;;
	0) exit 0 ;;
	*) echo -e "\033[0;31mWrong option\033[0m";;
esac
