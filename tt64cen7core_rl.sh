#!/usr/bin/env bash
# centos 7.0

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

STATIC="no"
INCTAIL="no"
INCTAILSTEPS=1
IP6PREFIXLEN=64

ETHNAME="eth0"
PROXYUSER="yag"
PROXYPASS="anhbiencong"

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

gen_static() {
    NETWORK_FILE="/etc/sysconfig/network-scripts/ifcfg-$ETHNAME"
    cat <<EOF
    sed -i '/^IPV6ADDR_SECONDARIES/d' $NETWORK_FILE && echo 'IPV6ADDR_SECONDARIES="$(awk -v IP6PREFIXLEN="$IP6PREFIXLEN" -F "/" '{print $5 "/" IP6PREFIXLEN}' ${WORKDATA} | sed -z 's/\n/ /g')"' >> $NETWORK_FILE
EOF
}

gen_proxy_file() {
    cat <<EOF
$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA})
EOF
}

update_proxies() {
    WORKDIR="/usr/local/3proxy/installer"
    WORKDATA="${WORKDIR}/data.txt"
    mkdir -p $WORKDIR
    eecho "Working folder = $WORKDIR"

    gen_data >$WORKDATA
    gen_iptables >$WORKDIR/boot_iptables.sh
    gen_ifconfig >$WORKDIR/boot_ifconfig.sh
    gen_static >$WORKDIR/boot_static.sh

    BOOTRCFILE="$WORKDIR/boot_rc.sh"

    REGISTER_LOGIC="systemctl restart network.service && bash ${WORKDIR}/boot_ifconfig.sh"
    if [[ $STATIC == "yes" ]]; then
        REGISTER_LOGIC="bash ${WORKDIR}/boot_static.sh && systemctl restart network.service"
    fi

    cat >$BOOTRCFILE <<EOF
bash ${WORKDIR}/boot_iptables.sh
${REGISTER_LOGIC}
systemctl restart 3proxy

# systemctl stop firewalld
# systemctl disable firewalld
# systemctl disable firewalld.service
EOF
    chmod +x ${WORKDIR}/boot_*.sh

    grep -qxF '* soft nofile 1024000' /etc/security/limits.conf || cat >>/etc/security/limits.conf <<EOF 

* soft nofile 1024000
* hard nofile 1024000
EOF

    grep -qxF "bash $BOOTRCFILE" /etc/rc.local || cat >>/etc/rc.local <<EOF 
bash $BOOTRCFILE
EOF
    chmod +x /etc/rc.local
    bash /etc/rc.local

    PROXYFILE=proxy.txt
    gen_proxy_file >$PROXYFILE
    eecho "Done with $PROXYFILE"

    UPLOAD_RESULT=$(curl -sf --form "file=@$PROXYFILE" https://cloud.ytbpre.com/upload_proxy.php)
    URL=$(echo "${UPLOAD_RESULT}" | awk '{print $1}')
    RESPONSE=$(echo "${UPLOAD_RESULT}" | awk '{$1=""; print $0}')

    eecho "Proxy is ready! Format IP:PORT:LOGIN:PASS"
    eecho "Upload result:"
    echo "${RESPONSE}"
    eecho "Upload result URL:"
    echo "${URL}"
    eecho "Password: ${PROXYPASS}"
}

update_proxies

