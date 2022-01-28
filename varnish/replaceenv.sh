#!/bin/bash
envs=`printenv`

for env in $envs
do
    IFS== read name value <<< "$env"

    sed -i "s|\${${name}}|${value}|g" /etc/varnish/default.vcl
done