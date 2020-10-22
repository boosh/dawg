#!/usr/bin/env bash
set -eo pipefail

function usage() {
  cat <<EOF
Update ydns.

Usage: $1 YDNS-URL CREDENTIALS

Note:
CREDENTIALS      In the form username:password (password can also be an API key)
EOF

  exit 1
}

url=$1
creds=$2

if [[ "$creds" == "" ]]; then
  usage $0
fi

ext_if=$(ip route sh | awk '$1 == "default" { print $5 }')
ext_ip=$(ip addr sh "$ext_if" | grep 'inet ' | xargs | awk -F'[ /]' '{ print $2 }')

curl --basic -u "$creds" "https://ydns.io/api/v1/update/?host=$url&ip=$ext_ip"
