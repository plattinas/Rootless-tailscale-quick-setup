#! /bin/bash

init_term(){
	shopt -s extglob #enable glob expansions
	printf '\e[?1049h' #enable alternate buffer
	printf '\e[H' #move cursor home
}

deinit_term(){
	shopt -u extglob #disable glob expansions
	printf '\e[?1049l' #disable alternate buffer
	printf '\e[?25h' #show the cursor
}

normal_exit(){
	local do_clean

	deinit_term
	source $HOME/.bashrc
	echo
	read -p "Clean instalation files? [Y/n]: " do_clean
	if [[ -z $do_clean ]];then
		echo "Cleaning files"
		clean
	elif [[ "${do_clean,,}" == "yes" || "${do_clean,,}" == "y" ]];then
		echo "Cleaning files"
		clean
	elif [[ "${do_clean,,}" == "no" || "${do_clean,,}" == "n" ]];then
		echo "Nothing done"
	else
		echo "Nothing done"
	fi

	exit 0
}

error_exit(){
	local log=$1
	
	deinit_term

	echo "[ERR]$log". Exiting... #Display error cause and exit with error code
	exit 1
}

exit_type(){
	if [[ -z $1 ]];then
		normal_exit
	else
		trap - EXIT
		error_exit "$1"
	fi
}

clean(){
	rm -r $HOME/tailscale_*.tgz $HOME/tailscale/systemd
	echo "Done!"
}

check_valid(){
	#Discard unwanted values
	arr_versions[0]=''
	arr_versions[-1]=''
	arr_versions[-2]=''
	
	#Take only the clean values and remake the array
	local i
	local new_index=0
	local clean_version=''

	for i in ${!arr_versions[@]}; do
		if [[ $(($i%2)) != 0 ]]; then
			clean_version="${arr_versions[$i]//'">'/}"
			clean_arr_versions[$new_index]=$clean_version
			((new_index++))
		fi
	done

	unset clean_arr_versions[-1]
}

tail_download(){	
	local arr_len=$((${#clean_arr_versions[@]}-1))
	local version	
	
	for j in ${!clean_arr_versions[@]}; do
		echo "[$j] ${clean_arr_versions[$j]}"
	done

	read -p "Select version [Default=1]: " version	
	if [[ -z $version ]];then
		version=1 #defaults to amd64 if empty
	elif (( $version > $arr_len ));then
		exit_type "Selected version index does not exist"
	fi
	echo "Downloading tailscale_${clean_arr_versions[$version]}"
	curl -O "https://pkgs.tailscale.com/stable/tailscale_${clean_arr_versions[$version]}"

	tail_install
}

tail_install(){
	local ti_source_file="\n#Tailscale\n\
		export PATH=\"\$HOME/tailscale:\$PATH\"\n\
		alias tailscale='tailscale --socket=\$HOME/tailscale/tailscaled.sock'"
	
	local bash_append="\n#Tailscale\n\
			export ti_TAILSCALE_INSTALLED="TRUE"\n\
			source $HOME/tailscale/.tailscale_bashrc\n"
	
	tar -xvf $HOME/tailscale_*.tgz
	mv $HOME/tailscale_*/ $HOME/tailscale/

	#check if we already have a tailscale source file from this script
	if [[ -z "$ti_TAILSCALE_INSTALLED" ]];then
		echo -e $bash_append >> $HOME/.bashrc #append to the end f bashrc
	fi
	#create a file outside user bashrc and source it
	echo -e $ti_source_file > $HOME/tailscale/.tailscale_bashrc
	source $HOME/.bashrc
	
	configure_systemd
}

configure_systemd(){
	local tailscaledservice="\
		[Unit]\n\
		Description=Tailscale node agent\n\
		Documentation=https://tailscale.com/kb/\n\
		Wants=network-pre.target\n\
		After=network-pre.target NetworkManager.service systemd-resolved.service\n\
		\n\
		[Service]\n\
		ExecStart=%h/tailscale/tailscaled \
			--state=%h/tailscale/tailscaled.state \
			--socket=%h/tailscale/tailscaled.sock \
			-tun=userspace-networking --port=41641\n\
		ExecStopPost=%h/tailscale/tailscaled --cleanup\n\
		\n\
		Restart=always\n\
		RestartSec=5\n\
		\n\
		StandardOutput=append:%h/tailscale/tailscaled.log\n\
		StandardError=append:%h/tailscale/tailscaled.log\n\
		\n\
		[Install]\n\
		WantedBy=default.target"

	echo -e "${tailscaledservice//$'\t'/}" > $HOME/.config/systemd/user/tailscaled.service
	
	systemctl --user daemon-reload
	systemctl --user enable --now tailscaled.service
}

main(){
	trap exit_type EXIT
	echo -n "Searching versions..."	
	TAILSCALE_CURL=$(curl -s -o/dev/stdout -D/dev/null https://pkgs.tailscale.com/stable/)
	TAILSCALE_PKG_LIST="${TAILSCALE_CURL//tailscale_/*}"
	IFS='*' read -r -a arr_versions <<< "${TAILSCALE_PKG_LIST//$'\n'/}"
	
	init_term
	check_valid
	tail_download
}

main
