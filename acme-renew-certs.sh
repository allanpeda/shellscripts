#!/bin/ksh
# Time-stamp: <>

get_sites(){
    local htconf="/etc/httpd.conf"
    awk '"server" == $1 {sub(/^\"/,"",$2); sub(/\"$/,"",$2); print $2}' "$htconf"
}

# sidestep subshell scope
check_reload(){
    get_sites | while IFS= read -r site
    do
        if /usr/sbin/acme-client "$site"
        then
            echo "1"
        fi
    done
}

if check_reload | grep -q .
then
    /usr/sbin/rcctl reload httpd
fi
