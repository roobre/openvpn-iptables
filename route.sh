#!/bin/bash

TABLE='pia-vpn'
MARK='0x1'
PREFERENCE='32000'

iptables='/usr/bin/iptables'

# Housekeeping

## Clean nat table
$iptables -t nat -F

## Clean ip route table
ip route flush table $TABLE

## Clean ip rule
ip rule del fwmark $MARK lookup $TABLE 2> /dev/null

if [ "$1" == "start" ]; then
	# Disable source route checking
	sysctl -w net.ipv4.conf.all.rp_filter=0 > /dev/null
	sysctl -w net.ipv4.conf.$dev.rp_filter=0 > /dev/null

	## Mangle source ip if wrong
	$iptables -t nat -I POSTROUTING ! -s $ifconfig_local -o $dev -j SNAT --to-source $ifconfig_local

	## Add VPN route to table
	ip route add default via $route_vpn_gateway dev $dev src $ifconfig_local table $TABLE
	## Add VPN endpoint through current default route
	ip route add $(ip route | grep default | sed "s/default/$trusted_ip/") table $TABLE
	## Add other routes except default and gateways, which are the ones overriden
	IFS=$'\n'
	for r in $(ip route show table main | grep -v '^default'); do
	unset IFS
		ip route add $r table $TABLE >> /tmp/routes
	done

	## Add ip rule to route marked traffic using table $TABLE
	ip rule add fwmark $MARK lookup $TABLE preference $PREFERENCE
	## Add ip rule to route PIA host through the main route
	#ip rule add to $trusted_ip lookup main preference 32000
fi

