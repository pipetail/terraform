#!/usr/bin/env bash
set -eo pipefail

export DEBIAN_FRONTEND=noninteractive

# Wait until system initialization is finished
echo "Waiting for cloud-init to finish"
/usr/bin/cloud-init status --wait

# Install required packages
apt update
apt -y upgrade
apt -y install awscli jq wireguard

install -d -m 0700 /etc/wireguard
install -d -m 0755 /usr/local/share/wireguard
install -m 0644 /tmp/wg0.conf.tftpl /usr/local/share/wireguard/wg0.conf.tftpl
install -m 0755 /tmp/configure-wireguard.sh /usr/local/sbin/configure-wireguard
install -m 0644 /tmp/wireguard-runtime.service /etc/systemd/system/wireguard-runtime.service

# uncomment some lines
sed -i '/#net.ipv4.ip_forward=1/s/^#//g' /etc/sysctl.conf
sed -i '/#net.ipv6.conf.all.forwarding=1/s/^#//g' /etc/sysctl.conf

sysctl -p

systemctl daemon-reload
systemctl disable wg-quick@wg0.service
systemctl enable wireguard-runtime.service
