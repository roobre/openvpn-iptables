# Routing certain traffic through a VPN using iptables rules

This script/setup is meant to allow routing certain specific traffic (defined by iptables rules)
through an OpenVPN instance.

It should not conflict with another running openVPN instances, local routes, and so on.


# Setting up

## 1. Create a new routing table

This step must be done only once, so it's not handled by the script. You can add a new routing table
by issuing the following command:

    echo "200   pia-vpn" >> /etc/iproute2/rt_tables

`pia-vpn` is the name I chose for the table. If you wish to change it, remember to modify the `route.sh` script
accordingly.

## 2. Modify openVPN config file to call the script.

Add the following to your openVPN config file:

    # Ignore routes pushed by the server
    route-noexec
    
    route-up "path/to/route.sh start"
    route-pre-down "path/to/route.sh stop"
    
    # Allow user-defined script execution
    script-security 2

## 3. Create your iptables rules to mark packets at will

My personal favourite way is to call iptables-restore after connecting to a network profile, but you can use whichever
method you like. This rules won't break internet connection if the VPN is down, so restoring them on boot is perfectly
fine if you want.

Here is an example configuration:

    [root@Archpv3]# ~> cat /etc/iptables/default.mangle.rules 
    *mangle

    # Rules
    # =====

    # Exclude SSH
    -A OUTPUT -p tcp --dport 22 -j ACCEPT

    # Exclude HTTPs to a host
    #-A OUTPUT -d tenshi.com.es -p tcp --dport 443 -j ACCEPT


    # Mark to route the rest over VPN
    -A OUTPUT -j MARK --set-xmark 0x1/0xffffffff

    COMMIT
