# Routing certain traffic through a VPN using iptables rules

This script/setup is meant to allow routing certain specific traffic (defined by iptables rules)
through an OpenVPN instance.

It should not conflict with another running openVPN instances, local routes, and so on.


# Setting up

## 1. Modify openVPN config file to call the script.

Add the following to your openVPN config file:

    # Ignore routes pushed by the server
    route-noexec
    
    route-up "path/to/route.sh start"
    route-pre-down "path/to/route.sh stop"
    
    # Allow user-defined script execution
    script-security 2

## 2. Create your iptables rules to mark packets at will

My personal favourite way is to call iptables-restore after connecting to a network profile, but you can use whichever
method you like. This rules won't break internet connection if the VPN is down, so restoring them on boot is perfectly
fine if you want.

Here is an example configuration:

### `[root@Archpv3]# ~> cat /etc/iptables/default.mangle.rules`

    *mangle

    # Rules
    # =====

    # Exclude SSH
    -A OUTPUT -p tcp --dport 22 -j ACCEPT

    # Exclude HTTPs to a host
    -A OUTPUT -d tenshi.com.es -p tcp --dport 443 -j ACCEPT

    # Exclude other OpenVPN instances (to avoid sending vpn traffic over another vpn)
    -A OUTPUT -d tenshi -p udp --dport 1194 -j ACCEPT
    
    # Exclude local networks (routes which exist when the script is run are copied to the
    #  vpn table, so this isn't really _necessary_. But it can help in some scenarios.
    -A OUTPUT -d 10.0.0.0/8 -j ACCEPT
    -A OUTPUT -d 192.168.0.0/16 -j ACCEPT

    # Mark to route the rest over VPN
    -A OUTPUT -j MARK --set-xmark 0x1/0xffffffff

    COMMIT
