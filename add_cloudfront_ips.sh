#!/bin/bash -e

if [[ ! $(command -v jq) ]]; then
    echo "Install jq"
    exit 1
fi


cloudfront_ips=$(curl -s http://d7uri8nf7uskq.cloudfront.net/tools/list-cloudfront-ips | jq -r '.CLOUDFRONT_GLOBAL_IP_LIST | join(";\nset_real_ip_from ")';)

cat << EOF > ./tmp-ips
set_real_ip_from 10.0.0.0/8;
set_real_ip_from 127.0.0.1/32;
set_real_ip_from 52.208.24.161/32;
set_real_ip_from 52.208.1.143/32;
set_real_ip from 52.51.250.21/32;
set_real_ip_from $cloudfront_ips;
EOF

# Taken from here: https://stackoverflow.com/a/6790967/1477072
sed '/__SET_REAL_IP_FROM__/{
    s/__SET_REAL_IP_FROM__//g
    r tmp-ips
}' nginx.conf.orig > nginx.conf

rm tmp-ips
