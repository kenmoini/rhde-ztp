#!/bin/bash

echo "Starting nginx server..."

/usr/sbin/nginx -c /etc/nginx/nginx.conf -e /dev/stderr
