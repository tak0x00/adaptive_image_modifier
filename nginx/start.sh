#!/bin/sh
sed -i -e "s/ORIGIN_DOMAIN/$ORIGIN_DOMAIN/g" /etc/nginx/nginx.conf
cat /etc/nginx/nginx.conf
nginx -g "daemon off;"