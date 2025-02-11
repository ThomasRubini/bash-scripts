#!/bin/bash

# Récupérer la plage du réseau
# Récupérer l'adresse la plus haute
# Récupérer l'adresse la plus haute
# Boucler entre les 2 pour ping les machines
# Si une machine répond
#  On ping les ports qui nous intéresse et on note les résultats
# Si elle ne répond pas
#  On passe à la suivante

ports=(21 22 23 80 443 8080)

echo "--- Starting logs ---"

# Parse the IP address of the given interface
# $1 - Interface name
# Return - The IP address of the interface, without subnet
parse_ip() {
    ip_with_mask=$(ip a | grep -A 2 ": $1" | tail -n 1 | sed -E 's/.*inet ([^ ]*) .*/\1/')
    echo $(echo $ip_with_mask | cut -d'/' -f1)
}

# Parse the subnet
#
# Return - list of subnet <IP>/<MASK>
parse_subnet() {
    subnet_part=$(ip a | grep -o "inet .* brd" | sed 's/[[:space:]]\+/-/g' | cut -d "-" -f 2) 
    echo "$subnet_part"
}

# Source: https://stackoverflow.com/a/10768196
# Translates an IP to decimal form
# $1 - IP address to translate
# Return - The IP address in decimal form
ip2dec () {
    local a b c d ip=$@
    IFS=. read -r a b c d <<< "$ip"
    printf '%d\n' "$((a * 256 ** 3 + b * 256 ** 2 + c * 256 + d))"
}

# Translates decimal number to IP adress
# $1 - decimal IP address to translate
# Return - The IP address
dec2ip () {
    local ip delim dec=$@
    for e in {3..0}
    do
        ((octet = dec / (256 ** e) ))
        ((dec -= octet * 256 ** e))
        ip+=$delim$octet
        delim=.
    done
    printf '%s\n' "$ip"
}
# Get the minimal IP in the network, assuming a /24 subnet
# $1 - IP address to get the smallest IP from
# Return - The smallest IP in the network
get_min_ip() {
    ip_part=$(echo "$1" | cut -d'.' -f1,2,3)
    echo "$ip_part.1"
}

# Scan a specific IP address to check if it is reachable
# $1 - The IP address to scan, in numeric form
scan_ip() {
    ip=$(dec2ip $1)
    mac=$(ip_to_mac $ip)
    constructor=$(get_oui_constructor $mac)
    if [ "$constructor" == "Cisco Systems, Inc" ] || [ "$constructor" == "NETGEAR" ]; then
        ports=(44 80 23)
    else
        ports=(21 22 23 80 443 8080)
    fi

    output=$(ping $1 -c 1 -W 0.5)
    if [ $? -eq 0 ]
    then
        echo "MAC Address: $(ip_to_mac $ip)"
        echo "Constructor: $constructor"
        echo -e "$ip\t| Response acknowledged"
        for i in "${ports[@]}"
        do
            ping_ip_port $1 $i
        done
        echo -e "----------------------"
    fi
}

get_oui() {
    echo $1 | cut -d':' -f1-3 | sed s/://g
}

# $1 - MAC address
# Return - The company of the MAC address
get_oui_constructor() {
    OUI=$(get_oui $1)
    IEEE_FILE="/var/lib/ieee-data/oui.csv"
    echo $(cat $IEEE_FILE | grep -i ",$OUI," | cut -d',' -f3)
}

ip_to_mac() {
    ip n | grep "$1 " | cut -d' ' -f5
}

# Scan every IP address in a /24 subnet
# Assumes the network starts from the minimal IP address (`min_ip_dec`)
# Iterates through all possible host addresses in the range (from .1 to .254)

scan_every_addr(){
    for i in {0..255}; do
        ip_to_scan=$((min_ip_dec+i))
        scan_ip $ip_to_scan
    done
}

# Check if a specific port is open on a given IP address
# $1 - The IP address to ping
# $2 - The port to test}
ping_ip_port() {
    output=$(ping $1 -p $2 -c 1 -W 0.5)
 
    if [ $? -eq 0 ]
    then
        echo -e "$(dec2ip $1)\t| Port $2 open"
    else
        echo -e "$(dec2ip $1)\t| Port $2 closed"
    fi

}


iface_ip=$(parse_ip "vlan254")
echo "IP address: $iface_ip"

min_ip=$(get_min_ip $iface_ip)
echo "Minimal IP in network: $min_ip"

min_ip_dec=$(ip2dec $min_ip)
echo "(Decimal form: $min_ip_dec)"

echo "Starting ping.."
scan_every_addr
