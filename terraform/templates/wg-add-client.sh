#!/usr/bin/env bash

PORT=21923
INT_NET_ADDR=10.0.0

function generate_keys() {
  local name=$1

  wg genkey | tee /etc/wireguard/${name}_private.key | wg pubkey > /etc/wireguard/${name}_public.key
  chmod 600 /etc/wireguard/${name}_private.key
}

function add_client() {
  local name=$1
  local ext_ip=$2
  local port=$3
  local int_net_addr=$4

  cat >> /etc/wireguard/wg0.conf <<EOF
[Peer]
# $name
PublicKey = $(cat /etc/wireguard/${name}_public.key)
PresharedKey = $(cat /etc/wireguard/wgpsk.key)
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = $ext_ip:$port
PersistentKeepalive = 25

EOF

cat > /etc/wireguard/client_$name.conf <<EOF
[Interface]
Address = $int_net_addr.$(shuf -i 2-255 -n 1)/32
PrivateKey = $(cat /etc/wireguard/${name}_private.key | tr -d '\n')
DNS = 1.1.1.1

[Peer]
PublicKey = $(cat /etc/wireguard/server_public.key | tr -d '\n')
PresharedKey = $(cat /etc/wireguard/wgpsk.key | tr -d '\n')
Endpoint = $ext_ip:$port
AllowedIPs = 0.0.0.0/0, ::/0
EOF
}

name=$1

ext_if=$(ip route sh | awk '$1 == "default" { print $5 }')
ext_ip=$(ip addr sh "$ext_if" | grep 'inet ' | xargs | awk -F'[ /]' '{ print $2 }')

generate_keys $name

add_client $name $ext_ip $PORT $INT_NET_ADDR