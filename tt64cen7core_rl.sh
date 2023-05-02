#!/usr/bin/env bash

GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

eecho() {
    echo -e "${GREEN}$1${NC}"
}

if [ $# -eq 0 ] || [ $1 -lt 1 ] || [ $1 -gt 10000 ]; then
    eecho "Usage: $0 <number_of_proxies>"
    exit 1
fi
PROXYCOUNT=$1

ETHNAME="eth0"
PROXYUSER="yag"
PROXYPASS="anhbiencong"

clean_iptables() {
    iptables -S | grep "dport 23000:" | sed 's/-A/-D/' | while read rule; do
        iptables ${rule}
    done
}

clean_ifconfig() {
    grep -E "inet6.+${ETHNAME}$" /etc/sysconfig/network-scripts/ifcfg-${ETHNAME} | awk -F "/" '{print $1}' | while read line; do
        ifconfig $line del
    done
}

gen_data() {
    array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)
    ip64() {
        echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
    }
    seq $PROXYCOUNT | while read idx; do
        port=$(($idx+23000))
        echo "$PROXYUSER/$PROXYPASS/$IP4/$port/$IP6PREFIX:$(ip64):$(ip64):$(ip64):$(ip64)"
    done
}

gen_iptables() {
    cat <<EOF
$(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA})
EOF
}

gen_ifconfig() {
    cat <<EOF
$(awk -v ETHNAME="$ETHNAME" -v IP6PREFIXLEN="$IP6PREFIXLEN" -F "/" '{print "ifconfig " ETHNAME " inet6 add " $5 "/" IP6PREFIXLEN}' ${WORKDATA})
EOF
}

clean_iptables
clean_ifconfig

gen_data > data.txt
gen_iptables > boot_iptables.sh
gen_ifconfig > boot_ifconfig.sh

chmod +x boot_*.sh

systemctl restart network.service && bash boot_ifconfig.sh
bash boot_iptables.sh
systemctl restart 3proxy

PROXYFILE=proxy.txt
awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' data.txt > $PROXYFILE

eecho "Done with $PROXYFILE"
