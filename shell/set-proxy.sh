#!/bin/bash
set -e

function usage () {
    echo "Usage: $0 [OPTIONS] PROXYADDRESS [NOPROXYADDRESSES]"
    echo
    echo "Options:"
    echo "-r    Removes proxy settings. No need to specify further parameters."
    echo
    echo "Notes:"
    if [ "$(id -ur)" -ne 0 ]; then
        echo "* MUST be run with root privileges"
    fi
    echo "* PROXYADDRESS should include the protocol and port number. E.g. http://proxy:8080"
    echo "* NOPROXYADDRESSES should be comma-separated, without spaces. E.g. 192.168.125.4,192.168.125.5"
    echo "  If not specified, a set of sequential IP addresses will be generated automatically."
    echo "  The range can be controlled using environment variables, as follows:"
    echo "  \$NETPREFIX.\$IPSTART through \$NETPREFIX.\$IPEND"
    echo "  The default range is 192.168.125.10 through 192.168.125.20"
    echo
}

function generate_no_proxy() {
    local RESULT=""
    for ((i=IPSTART; i<=IPEND; i++)); do
        RESULT+="${NETPREFIX}.$i,"
    done
    RESULT=${RESULT%,}
    echo "$RESULT"
}

function valid_proxy_format() {
    local REX="^http(s{0,1})://([^/:]*)(:[0-9]{2,6}){0,1}$"
    [[ "$1" =~ $REX ]]
    return $?
}

if [ "$1" == "" ] ; then
    usage

    exit 1
fi

if [ "$(id -ur)" -ne 0 ]; then
    echo "$0 can only be run as root. Use sudo."
    exit 1
fi

if [ "$1" == "-r" ]; then
    echo "Removing user proxy..."
    unset http_proxy
    unset https_proxy
    unset no_proxy
    rm -f /etc/profile.d/kutti-proxy.sh
    echo "Done."

    echo "Removing daemon proxy..."
    rm -f /etc/systemd/system.conf.d/kutti-proxy.conf
    echo "Restarting daemons..."
    systemctl daemon-reload
    systemctl restart containerd kubelet
    echo "Done."

    echo "Proxy configuration removed. A reboot may be required."
    exit 0
fi

PROXYADDRESS=$1

if ! valid_proxy_format "$PROXYADDRESS"; then
    echo "Error: The proxy address should be in the format: http[s]://HOST[:PORT]" >&2
    usage

    exit 1
fi

NOPROXYADDRESSES=$2

if [ "$NOPROXYADDRESSES" = "" ]; then
    NETPREFIX=${NETPREFIX:-192.168.125}
    IPSTART=${IPSTART:-10}
    IPEND=${IPEND:-20}

    NOPROXYADDRESSES=$(generate_no_proxy)
fi

echo "Setting up user proxy..."

cat  <<ENDPROXY >>/etc/profile.d/kutti-proxy.sh
export http_proxy=${PROXYADDRESS}
export https_proxy=${PROXYADDRESS}
export no_proxy=127.0.0.1,localhost,${NOPROXYADDRESSES}
ENDPROXY

# shellcheck source=/dev/null
source /etc/profile.d/kutti-proxy.sh

echo "Done."

echo "Setting up daemon proxy..."

if [ ! -d /etc/systemd/system.conf.d ]; then
    mkdir -p /etc/systemd/system.conf.d
fi

cat >>/etc/systemd/system.conf.d/kutti-proxy.conf <<ENDDAEMON
[Manager]
DefaultEnvironment="http_proxy=${PROXYADDRESS}"
DefaultEnvironment="https_proxy=${PROXYADDRESS}"
DefaultEnvironment="no_proxy=127.0.0.1,localhost,${NOPROXYADDRESSES}"
ENDDAEMON

echo "Restarting daemons..."
systemctl daemon-reload
systemctl restart containerd kubelet

echo "Done."

echo "Proxy configured. A reboot may be required."
exit 0
