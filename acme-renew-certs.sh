#!/bin/ksh
# Time-stamp: <2026-04-18 19:18:15 allan>

set -eu

get_sites(){
    local htconf="/etc/httpd.conf"
    awk '"server" == $1 {sub(/^\"/,"",$2); sub(/\"$/,"",$2); print $2}' "$htconf"
}

get_pem(){
    perl -ne 'BEGIN { $target = shift @ARGV }
    if (/^domain\s+(\S+)/) { $in_block = ($1 eq $target); }
    if ($in_block && /domain full chain certificate\s+"([^"]+)"/)
      { print "$1\n"; exit }' "$1" "$2"
}

# sidestep subshell scope
check_reload(){
    local site pem
    get_sites | while IFS= read -r site
    do
        pem="$(get_pem "$site" '/etc/acme-client.conf')"
        # testing the update modification time is easier to do repeatledly
        '/usr/sbin/acme-client' -f '/etc/acme-client.conf' "$site" &>/dev/null || :
        if (( $(date +%s) - $(stat -f %m "$pem") < 3600 ))
        then
            echo "1"
        fi
    done
}

if check_reload | grep -q .
then
   /usr/sbin/rcctl reload httpd
   /usr/sbin/rcctl reload relayd
fi
