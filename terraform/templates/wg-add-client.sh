#!/usr/bin/env bash
set -eo pipefail

PORT=21923
INT_NET_ADDR=10.0.0

function usage() {
  cat <<EOF
Create a new client or add an existing client to the Wireguard config.

Usage: $1 MODE NAME [CLIENT_IP] [PUBLIC_KEY]

Parameters:
MODE        Either 'add' or 'create'. If 'add', pass the 'CLIENT_IP' and 'PUBLIC_KEY' arguments
NAME        Client name
CLIENT_IP   If adding a client, the IP to assign it within the VPN subnet
PUBLIC_KEY  The client's public key

EOF

  exit 1
}

function generate_keys() {
  local name=$1

  wg genkey | tee /etc/wireguard/${name}_private.key | wg pubkey >/etc/wireguard/${name}_public.key
  chmod 600 /etc/wireguard/${name}_private.key
}

# Writes a config for a new client. Generates a client key then deletes it.
# Returns the client's VPN IP.
function write_client_config() {
  local name=$1
  local ext_ip=$2
  local port=$3
  local int_net_addr=$4

  generate_keys $name

  client_ip=$int_net_addr.$(shuf -i 2-255 -n 1)/32

  cat >/etc/wireguard/client_$name.conf <<EOF
[Interface]
Address = $client_ip
PrivateKey = $(cat /etc/wireguard/${name}_private.key | tr -d '\n')
DNS = 1.1.1.1

[Peer]
PublicKey = $(cat /etc/wireguard/server_public.key | tr -d '\n')
Endpoint = $ext_ip:$port
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

  rm /etc/wireguard/${name}_private.key
  echo $client_ip
}

# Updates the Wireguard server config to allow a client to connect
function update_server_config() {
  local name=$1
  local client_ip=$2
  local public_key=$3

  cat >>/etc/wireguard/wg0.conf <<EOF
[Peer]
# $name
PublicKey = $public_key
AllowedIPs = $client_ip

EOF
}

function main() {
  local mode=$1
  local name=$2
  local client_ip=$3
  local public_key=$4

  if [[ "$name" == "" ]]; then
    usage
  fi

  ext_if=$(ip route sh | awk '$1 == "default" { print $5 }')
  ext_ip=$(ip addr sh "$ext_if" | grep 'inet ' | xargs | awk -F'[ /]' '{ print $2 }')

  if [[ "$mode" == "create" ]]; then
    client_ip=$(write_client_config $name $ext_ip $PORT $INT_NET_ADDR)
    update_server_config $name $client_ip "$(cat /etc/wireguard/${name}_public.key)"

    rm /etc/wireguard/${name}_public.key
    cat /etc/wireguard/client_$name.conf
  else
    if [[ "$public_key" == "" ]]; then
      usage
    fi

    # just add the client to the server config
    update_server_config $name $client_ip $public_key
  fi

  systemctl restart wg-quick@wg0
}

if [[ "$1" == "help" ]]; then
  usage $1
fi

main $1 $2 $3 $4
