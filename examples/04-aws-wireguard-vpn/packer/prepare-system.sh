#!/usr/bin/env bash
set -eo pipefail

export DEBIAN_FRONTEND=noninteractive

# Wait until system initialization is finished
echo "Waiting for cloud-init to finish"
/usr/bin/cloud-init status --wait

# Install required packages
apt update
apt -y upgrade
apt -y install jq wireguard

mkdir -p /etc/wireguard/keys
cd /etc/wireguard/keys
umask 077
echo "${PRIVATE_KEY}" | tee privatekey | wg pubkey > publickey

_PRIVATE_KEY_PLACEHOLDER="${PRIVATE_KEY}" envsubst < /tmp/wg0.conf.tpl > /etc/wireguard/wg0.conf

# uncomment some lines
sed -i '/#net.ipv4.ip_forward=1/s/^#//g' /etc/sysctl.conf
sed -i '/#net.ipv6.conf.all.forwarding=1/s/^#//g' /etc/sysctl.conf

sysctl -p

wg-quick up wg0
systemctl enable wg-quick@wg0
