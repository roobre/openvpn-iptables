#!/bin/bash

# ABOUT
# =====

# This script enables selective, iptables-based routing through an VPN instance.
# To achieve this, it swaps the default route of the default routing table with
# the openVPN gateway, and creates an auxiliar table with the original gateway, where
# marked packets are directed.
#
# For the iptables setup, please see the included `default.mangle.rules` file, or head to
# https://github.com/roobre/vpn-iptables.

# CONFIGURATION
# =============

# FWMark used in iptables.
MARK='0x1'

# Table name and ID. Change only if you care about the names.
TABLE='vpn'
TABLE_ID='200'

# Table preference. Must be lower than "main", which is 32766.
PREFERENCE='32000'

# Flush nat table
# If set to 1, nat table will be flushed every time this script is called.
# Setting this to 0 will prevent this behaviour, but an useless rule will be left
#  on the table every time the service is restarted.
# Set to zero only if you have other scripts/setups depending on the nat table.
FLUSH_NAT=true

# =============


# Housekeeping

# Clean nat table
## TODO: Avoid flushing the entire table, find some way to delete only the rules which can interfere.
[[ $FLUSH_NAT ]] && iptables -t nat -F

# Clean ip rule
ip rule del fwmark $MARK lookup $TABLE 2> /dev/null

# Clean ip route table
ip route flush table $TABLE


if [ "$1" == "start" ]; then
    # Add table to /etc/iproute2/rt_tables if missing
    grep -e "$TABLE_ID\s\+$TABLE$" /etc/iproute2/rt_tables &> /dev/null || echo -e "$TABLE_ID\t$TABLE" >> /etc/iproute2/rt_tables

    # Disable source route checking
    sysctl -w net.ipv4.conf.all.rp_filter=0 > /dev/null
    sysctl -w net.ipv4.conf.$dev.rp_filter=0 > /dev/null

    # Mangle source ip if wrong
    iptables -t nat -I POSTROUTING ! -s $ifconfig_local -o $dev -j SNAT --to-source $ifconfig_local

    # Add default route to VPN table
    ip route add default via $route_vpn_gateway dev $dev src $ifconfig_local table $TABLE

    # Add VPN endpoint through current default route, just in case
    #  the user don't exclude it via iptables
    ip route add $(ip route | grep default | sed "s/default/$trusted_ip/") table $TABLE

    # Copy non-default route to new table too
    while read r; do
            ip route add $r table $TABLE >> /tmp/routes
    done < <(ip route show table main | grep -v '^default')

    # Add ip rule to route marked traffic using table $TABLE
    ip rule add fwmark $MARK lookup $TABLE preference $PREFERENCE
fi
