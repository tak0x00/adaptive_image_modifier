#!/bin/bash
/bin/bash /replaceenv.sh
/usr/sbin/varnishd \
    -f /etc/varnish/default.vcl \
    -a http=:80,HTTP \
    -a proxy=:8443,PROXY \
    -p feature=+http2 \
    -s malloc,$VARNISH_SIZE \
    "$@"

varnishlog -i VCL_Log