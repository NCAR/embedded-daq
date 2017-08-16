#! /bin/sh

# Run this script like so:

# iptables-apply -t 30 -w /etc/network/isfs-iptables.rules -c /etc/network/isfs-iptables-setup.sh

# This will roll back the iptables rules if they block the current connection.  The
# 30-second timeout provides time to attempt a second connection and make sure it 
# succeeds before accepting the changes.

# Or, to immediately update the rules and the saved rules file, without the rollback
# check provided by iptables-apply:

# ./isfs-iptables-setup.sh > /etc/network/isfs-iptables.rules

# This is mostly extracted from raf-ac-firewall iptables-setup.sh script, but simplified
# to be independent of interfaces and to only filter input traffic.

# quit immediately on error, otherwise error messages tend to be missed
set -e
# but return firewall to open state on error (in case one is testing from off site)
#trap "{ /etc/init.d/iptables stop; }" ERR

# Flush tables
# flush (delete all rules one by one) all chains in the -t filter table
iptables -F
# delete every non-builtin chain in the table
iptables -X
iptables -Z

# Default policies.  Do not try to filter output traffic, only what is
# allowed from outside.
iptables -P INPUT DROP
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT

# allow anything on loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# allow anything on private networks, meaning we are behind one of our NAT
# routers
iptables -A INPUT --source 192.168.0.0/16 -j ACCEPT

# allow incoming ssh, rsync, and pings from UCAR networks
iptables -A INPUT -p tcp --dport rsync --source 128.117.0.0/16 -j ACCEPT
iptables -A INPUT -p tcp --dport ssh --source 128.117.0.0/16 -j ACCEPT
iptables -A INPUT -p icmp --source 128.117.0.0/16 -j ACCEPT

# also allow access to dsm raw sample TCP stream, but it needs to be
# allowed from anywhere to give flux2 at ARTSE the option to connect
# directly to pull samples.
iptables -A INPUT -p tcp --dport 30000 -j ACCEPT

# allow inbound packets for related and established connections
iptables -A INPUT -p icmp -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p udp -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow UDP NTP packets from Internet servers.  Actually, the lines above
# should take care of this I think, and only allow NTP packets from servers
# first contacted by this host.
#
#iptables -A INPUT -p udp --dport ntp -j ACCEPT

# accept fragments on any interface
iptables -A INPUT -f -j ACCEPT

info() {
    echo "# Generated by $0 on `date`"
    echo "# Note running this script changes the firewall temporarily, until the next boot."
    echo "# To make the changes permanent, redirect the output to /etc/network/iptables"
    echo "# by doing: $0 > /etc/network/iptables"
}

# Put the info messages at the beginning and end of output
info
iptables-save
info

