#!/usr/bin/env bash
set -exuo pipefail

NETMASK=/24
NAMESERVER=1.1.1.1
INT_NET_ADDR=10.0.0.1
PORT=21923

function write_server_config() {
  local private_key=$1
  local addr=$2
  local netmask=$3
  local port=$4
  local ext_if=$5
  
  cat > /etc/wireguard/wg0.conf <<EOF
# Server configuration
[Interface]
PrivateKey = $private_key
Address = ${addr}${netmask}    # Internal IP address of the VPN server.
ListenPort = $port
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $ext_if -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $ext_if -j MASQUERADE

EOF
}

ext_if=$(ip route sh | awk '$1 == "default" { print $5 }')
ext_ip=$(ip addr sh "$ext_if" | grep 'inet ' | xargs | awk -F'[ /]' '{ print $2 }')

wg genkey | tee /etc/wireguard/server_private.key | wg pubkey | tee /etc/wireguard/server_public.key
chmod 600 /etc/wireguard/server_private.key

sed -i -E 's/#(net.ipv4.ip_forward=1)/\1/' /etc/sysctl.conf
sysctl -p

ufw allow $PORT/udp

write_server_config $(cat /etc/wireguard/server_private.key | tr -d '\n') $INT_NET_ADDR $NETMASK $PORT $ext_if

systemctl start wg-quick@wg0
systemctl enable wg-quick@wg0
