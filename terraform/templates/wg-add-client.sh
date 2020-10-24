#!/usr/bin/env bash
set -eo pipefail

PORT=21923
INT_NET_ADDR=10.0.0

function usage() {
  cat <<EOF
Create a new client or add an existing client to the Wireguard config.

Usage: $0 [OPTIONS] MODE NAME

Parameters:
MODE        Either 'add' or 'create'. If 'add', extra options are required. See below.
NAME        Client name

Options:
 -c CLIENT_IP      If adding a client, the IP to assign it within the VPN subnet. Required when mode is 'add'.
 -e ENDPOINT       Server domain name. If not given, the server's public IP will be automatically detected and used.
 -k PUBLIC_KEY     The client's public key. Required when mode is 'add'.

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
  local endpoint=$2
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
Endpoint = $endpoint:$port
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
  local endpoint=$5

  if [[ "$name" == "" ]]; then
    usage
  fi

  if [[ "$endpoint" == "" ]]; then
    ext_if=$(ip route sh | awk '$1 == "default" { print $5 }')
    endpoint=$(ip addr sh "$ext_if" | grep 'inet ' | xargs | awk -F'[ /]' '{ print $2 }')
  fi

  if [[ "$mode" == "create" ]]; then
    client_ip=$(write_client_config $name $endpoint $PORT $INT_NET_ADDR)
    update_server_config $name $client_ip "$(cat /etc/wireguard/${name}_public.key)"

    rm /etc/wireguard/${name}_public.key
    cat /etc/wireguard/client_$name.conf
    rm /etc/wireguard/client_$name.conf
  else
    if [[ "$public_key" == "" ]]; then
      usage
    fi

    # just add the client to the server config
    update_server_config $name $client_ip $public_key
  fi

  systemctl restart wg-quick@wg0
}

if [[ "$#" -lt 2 ]]; then
   usage
fi

optstring=":hc:e:k:"

client_ip=""
endpoint=""
public_key=""

while getopts ${optstring} arg; do
  case "${arg}" in
    c) client_ip="${OPTARG}" ;;
    e) endpoint="${OPTARG}" ;;
    k) public_key="${OPTARG}" ;;

    *)
      echo "Invalid option: -${OPTARG}."
      echo
      usage
      ;;
  esac
done
shift $((OPTIND -1))

main $1 $2 "$client_ip" "$public_key" "$endpoint"
