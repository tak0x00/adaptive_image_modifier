#!/bin/bash
/bin/bash /replaceenv.sh
/usr/sbin/varnishd \
    -f /etc/varnish/default.vcl \
    -a http=:80,HTTP \
    -a proxy=:8443,PROXY \
    -p feature=+http2 \
    -s malloc,$VARNISH_SIZE \
    -p thread_pools=4 \
    -p thread_pool_min=200 \
    -p thread_pool_max=4000 \
    -p thread_pool_add_delay=2 \
    -p listen_depth=4096 \
    -p first_byte_timeout=2s \
    -p max_retries=1
    "$@"

varnishlog -i VCL_Log