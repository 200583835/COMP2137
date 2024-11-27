#!/bin/bash

# Ignore TERM, HUP, and INT signals
trap '' TERM HUP INT

# Default values
verbose=0
desiredName=""
desiredIPAddress=""
hostName=""
hostIP=""
netplanFile="/etc/netplan/01-netcfg.yaml"

# Logger function for verbose output
log_message() {
    if [[ $verbose -eq 1 ]]; then
        echo "$1"
    fi
}

# Apply hostname changes
set_hostname() {
    currentName=$(hostname)
    if [[ "$currentName" != "$desiredName" ]]; then
        echo "$desiredName" > /etc/hostname
        hostnamectl set-hostname "$desiredName"
        sed -i "s/$currentName/$desiredName/g" /etc/hosts
        log_message "Hostname updated to $desiredName"
        logger "Hostname changed from $currentName to $desiredName"
    else
        log_message "Hostname already set to $desiredName"
    fi
}

# Apply IP address changes
set_ip_address() {
    # Find the active network interface
    activeInterface=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n 1)
    currentIP=$(hostname -I | awk '{print $1}')

    if [[ "$currentIP" != "$desiredIPAddress" ]]; then
        # Update /etc/hosts
        sed -i "/$currentIP/d" /etc/hosts
        echo "$desiredIPAddress $(hostname)" >> /etc/hosts

        # Update netplan configuration
        if [[ ! -f "$netplanFile" ]]; then
            cat <<EOF > "$netplanFile"
network:
  version: 2
  ethernets:
    $activeInterface:
      dhcp4: no
      addresses:
        - $desiredIPAddress/24
      gateway4: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
EOF
        fi
        netplan apply
        log_message "IP address updated to $desiredIPAddress on $activeInterface"
        logger "IP address changed to $desiredIPAddress on $activeInterface"
    else
        log_message "IP address already set to $desiredIPAddress"
    fi
}

# Add or update a host entry
update_host_entry() {
    grep -q "$hostIP $hostName" /etc/hosts
    if [[ $? -ne 0 ]]; then
        echo "$hostIP $hostName" >> /etc/hosts
        log_message "Added host entry: $hostName $hostIP"
        logger "Added host entry: $hostName $hostIP"
    else
        log_message "Host entry $hostName $hostIP already exists"
    fi
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -verbose)
            verbose=1
            shift
            ;;
        -name)
            desiredName=$2
            shift 2
            ;;
        -ip)
            desiredIPAddress=$2
            shift 2
            ;;
        -hostentry)
            hostName=$2
            hostIP=$3
            shift 3
            ;;
        *)
            echo "Unknown parameter: $1"
            exit 1
            ;;
    esac
done

# Apply changes
if [[ -n $desiredName ]]; then
    set_hostname
fi

if [[ -n $desiredIPAddress ]]; then
    set_ip_address
fi

if [[ -n $hostName && -n $hostIP ]]; then
    update_host_entry
fi
