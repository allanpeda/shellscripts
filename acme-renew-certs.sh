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

reported_end_date(){
    addr="$1"
    openssl s_client -connect "${addr}:443" \
        -servername "${addr}" </dev/null 2>/dev/null \
        | openssl x509 -noout -enddate
}

local_end_date(){
    local pem="$1"
    openssl x509 -in "$pem" -noout -enddate
}

# sidestep subshell scope
require_reload(){
    local site pem  redate ledate
    get_sites | while IFS= read -r site
    do
        pem="$(get_pem "$site" '/etc/acme-client.conf')"
        # testing the update modification time is easier to do repeatedly
        '/usr/sbin/acme-client' -f '/etc/acme-client.conf' "$site" &>/dev/null || :
        redate="$(reported_end_date "$site")"
        ledate="$(local_end_date "$pem")" 
        # echo "$ledate $redate $site $pem"
        if [[ "$redate" != "$ledate" ]]
        then
            echo 1
        fi
    done
}

if require_reload | grep -q .
then
   /usr/sbin/rcctl reload httpd
   /usr/sbin/rcctl reload relayd
fi
