_LIVE_AGENT_LIST=""
declare -a _LIVE_AGENT_SOCK_LIST
_LIVE_AGENT_SOCK_LIST=()

_debug_print() { [[ $_DEBUG -gt 0 ]] && printf "%s\n" $1; }

find_all_ssh_agent_sockets() {
	_SSH_AGENT_SOCKETS=`find /tmp/ -type s -name agent.\* 2> /dev/null | grep '/tmp/ssh-.*/agent.*'`
	_debug_print "$_SSH_AGENT_SOCKETS"
}
find_all_gpg_agent_sockets() {
	_GPG_AGENT_SOCKETS=`find /tmp/ -type s -name S.gpg-agent.ssh 2> /dev/null | grep '/tmp/gpg-.*/S.gpg-agent.ssh'`
	_debug_print "$_GPG_AGENT_SOCKETS"
}
find_all_gnome_keyring_agent_sockets() {
	_GNOME_KEYRING_AGENT_SOCKETS=`find /tmp/ -type s -name ssh 2> /dev/null | grep '/tmp/keyring-.*/ssh$'`
	_debug_print "$_GNOME_KEYRING_AGENT_SOCKETS"
}

test_agent_socket() {
	local SOCKET=$1
	SSH_AUTH_SOCK=$SOCKET ssh-add -l 2> /dev/null > /dev/null
	result=$?;
	_debug_print $result
	# contactible and has keys loaded
	[[ $result -eq 0 ]] && _KEY_COUNT=`SSH_AUTH_SOCK=$SOCKET ssh-add -l | wc -l | tr -d ' '`;
	# contactible, but no keys loaded
	[[ $result -eq 1 ]] && _KEY_COUNT=0;

	if [[ ( ( $result -eq 0 ) || ( $result -eq 1 ) ) ]]; then
		if [[ -n "$_LIVE_AGENT_LIST" ]]; then
			_LIVE_AGENT_LIST="${_LIVE_AGENT_LIST} ${SOCKET}:$_KEY_COUNT";
		else
			_LIVE_AGENT_LIST="${SOCKET}:$_KEY_COUNT";
		fi
		return 0
	fi
	return 1
}

find_live_gnome_keyring_agents() { for i in $_GNOME_KEYRING_AGENT_SOCKETS; do test_agent_socket $i; done; }

find_live_gpg_agents() { for i in $_GPG_AGENT_SOCKETS; do test_agent_socket $i; done; }

find_live_ssh_agents() { for i in $_SSH_AGENT_SOCKETS; do test_agent_socket $i; done; }

function fingerprints() {
    local file="$1"
    while read l; do
        [[ -n $l && ${l###} = $l ]] && ssh-keygen -l -f /dev/stdin <<<$l
    done < $file
}

find_all_agent_sockets() {
	_SHOW_IDENTITY=0
	[[ "$1" = "-i" ]] && _SHOW_IDENTITY=1;
	_LIVE_AGENT_LIST=
	find_all_ssh_agent_sockets
	find_all_gpg_agent_sockets
	find_all_gnome_keyring_agent_sockets
	find_live_ssh_agents
	find_live_gpg_agents
	find_live_gnome_keyring_agents
	_debug_print "$_LIVE_AGENT_LIST"
	_LIVE_AGENT_LIST=$(echo $_LIVE_AGENT_LIST | tr ' ' '\n' | sort -n -t: -k 2 -k 1 | uniq)
	_LIVE_AGENT_SOCK_LIST=()
	_debug_print "SORTED: $_LIVE_AGENT_LIST"

	[[ -e ~/.ssh/authorized_keys ]] && _FINGERPRINTS=$(fingerprints ~/.ssh/authorized_keys);

	if [[ $_SHOW_IDENTITY -gt 0 ]]; then
		i=0
		for a in $_LIVE_AGENT_LIST; do
			sock=${a/:*/}
			_LIVE_AGENT_SOCK_LIST[$i]=$sock
			# technically we could have multiple keys forwarded
			# But I haven't seen anyone do it
			akeys=$(SSH_AUTH_SOCK=$sock ssh-add -l)
			key_size=$(echo ${akeys} | awk '{print $1}')
			fingerprint=$(echo ${akeys} | awk '{print $2}')
			remote_name=$(echo ${akeys} | awk '{print $3}')
			[[ -e ~/.ssh/authorized_keys ]] && authorized_entry=$(fingerprints ~/.ssh/authorized_keys | grep $fingerprint)
			comment=$(echo ${authorized_entry} | awk '{print $3,$4,$5,$6,$7}')
			printf "export SSH_AUTH_SOCK=%s \t#%i) \t%s\n" "$sock" $((i+1)) "$comment"
			i=$((i+1))
		done
	else
		printf "%s\n" "$_LIVE_AGENT_LIST" | sed -e 's/ /\n/g' | sort -n -t: -k 2 -k 1
	fi
}

set_ssh_agent_socket() {
	if [ "$1" = "-c" -o "$1" = "--choose" ]; then
		find_all_agent_sockets -i

		[[ -z "$_LIVE_AGENT_LIST" ]] && echo "No agents found" && return 1;

		echo -n "Choose (1-${#_LIVE_AGENT_SOCK_LIST[@]})? "
		read choice
		if [[ -n "$choice" ]]; then
			n=$((choice-1))
			[[ -z "${_LIVE_AGENT_SOCK_LIST[$n]}" ]] && echo "Invalid choice" && return 1;
			echo "Setting export SSH_AUTH_SOCK=${_LIVE_AGENT_SOCK_LIST[$n]}"
			export SSH_AUTH_SOCK=${_LIVE_AGENT_SOCK_LIST[$n]}
		fi
	else
		# Choose the first available
		SOCK=$(find_all_agent_sockets|tail -n 1|awk -F: '{print $1}')
		[[ -z "$SOCK" ]] && return 1;
		export SSH_AUTH_SOCK=$SOCK
	fi

	return 0
}

ssh-find-agent() {
	if [ "$1" = "-c" -o "$1" = "--choose" ]; then
		set_ssh_agent_socket -c
		return $?
	elif [ "$1" = "-a" -o "$1" = "--auto" ]; then
		set_ssh_agent_socket
		return $?
	else
		find_all_agent_sockets -i
		return 0
	fi
}
