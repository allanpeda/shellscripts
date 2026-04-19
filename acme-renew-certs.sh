#!/bin/ksh
# Time-stamp: <2026-04-18 19:18:15 allan>

set -eu

get_sites(){
    local htconf="/etc/httpd.conf"
    awk '"server" == $1 {sub(/^\"/,"",$2); sub(/\"$/,"",$2); print $2}' "$htconf"
}

# sidestep subshell scope
check_reload(){
    local site pem
    get_sites | while IFS= read -r site
    do
        # testing the update modification time is easier to run repeatledly
        pem="$('/usr/sbin/acme-client' -v -f \
               '/etc/acme-client.conf' "$site" 2>&1 \
                  | awk '{sub(/:/,"",$2); print $2}')"
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
