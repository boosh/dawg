#!/usr/bin/env bash
set -exuo pipefail

NETMASK=/24
INT_NET_ADDR=10.0.0
PORT=21923
EXT_IF=$(ip route sh | awk '$1 == "default" { print $5 }')

function generate_keys() {
  local name=$1

  private_key_path=/etc/wireguard/${name}_private.key

  if [[ ! -f "$private_key_path" ]]; then
    wg genkey > "$private_key_path"
  fi

  if [[ ! -f /etc/wireguard/${name}_public.key ]]; then
  cat "$private_key_path" | wg pubkey | tee /etc/wireguard/${name}_public.key
  fi

  chmod 600 "$private_key_path"
}

function write_server_config() {
  local addr=$1
  local netmask=$2
  local port=$3
  local ext_if=$4

  if [[ ! -f /etc/wireguard/wg0.conf ]]; then
    cat > /etc/wireguard/wg0.conf <<EOF
# Server configuration
[Interface]
PrivateKey = $(cat /etc/wireguard/server_private.key | tr -d '\n')
Address = $addr.1$netmask
ListenPort = $port
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $ext_if -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $ext_if -j MASQUERADE
DNS = 1.1.1.1

EOF
  fi
}

generate_keys server

sed -i -E 's/#(net.ipv4.ip_forward=1)/\1/' /etc/sysctl.conf
sysctl -p

ufw allow $PORT/udp

write_server_config $INT_NET_ADDR $NETMASK $PORT $EXT_IF

systemctl start wg-quick@wg0
systemctl enable wg-quick@wg0
