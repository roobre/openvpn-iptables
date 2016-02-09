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

## FWMark used in iptables.
MARK='0x1'

## Table name and ID. Change only if you care about the names.
TABLE='vpn'
TABLE_ID='200'

## Table preference. Must be lower than "main", which is 32766.
PREFERENCE='32000'

## Flush nat table
### If set to 1, nat table will be flushed every time this script is called.
### Setting this to 0 will prevent this behaviour, but an useless rule will be left
###  on the table every time the service is restarted.
### Set to zero only if you have other scripts/setups depending on the nat table.
FLUSH_NAT=true

## Path to iptables binary
iptables='/usr/bin/iptables'
### Debian users should use this path instead:
#iptables='/sbin/iptables'

# =============


# Housekeeping

## Clean nat table
### TODO: Avoid flushing the entire table, find some way to delete only the rules which can interfere.
if $FLUSH_NAT; then $iptables -t nat -F; fi

## Clean ip rule
ip rule del fwmark $MARK lookup $TABLE 2> /dev/null

if [ "$1" == "start" ]; then
    ## Add table to /etc/iproute2/rt_tables if missing
    grep -e "$TABLE_ID\s\+$TABLE" /etc/iproute2/rt_tables || echo -e "$TABLE_ID\t$TABLE" >> /etc/iproute2/rt_tables

    # Disable source route checking
    sysctl -w net.ipv4.conf.all.rp_filter=0 > /dev/null
    sysctl -w net.ipv4.conf.$dev.rp_filter=0 > /dev/null

    ## Mangle source ip if wrong
    $iptables -t nat -I POSTROUTING ! -s $ifconfig_local -o $dev -j SNAT --to-source $ifconfig_local

    ## Clean ip route table
    ip route flush table $TABLE

    ## Copy default route to secondary table.
    ip route add $(ip route | grep default) table $TABLE
    
    ## Delete default route from `main` table.
    ip route del default

    ## Add new default route via VPN
    ip route add default via $route_vpn_gateway dev $dev src $ifconfig_local

	## Add ip rule to route marked traffic using table $TABLE
	ip rule add not fwmark $MARK lookup $TABLE preference $PREFERENCE
elif [ "$1" == "stop" ]; then
    ip route add $(ip route show table $TABLE | grep default)

    ## Clean ip route table
    ip route flush table $TABLE
fi

