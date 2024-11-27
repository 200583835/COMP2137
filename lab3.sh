#!/bin/bash

# Enable verbose mode if the -verbose flag is passed
verbose=0
if [[ $1 == "-verbose" ]]; then
    verbose=1
fi

# Function to log messages in verbose mode
log_message() {
    if [[ $verbose -eq 1 ]]; then
        echo "$1"
    fi
}

# Define variables for server names and IP addresses
server1="remoteadmin@server1-mgmt"
server2="remoteadmin@server2-mgmt"
configure_script="configure-host.sh"

# Test if the configure-host.sh script exists
if [[ ! -f "$configure_script" ]]; then
    echo "Error: $configure_script not found in the current directory."
    exit 1
fi

# Transfer the configuration script to server1
log_message "Transferring $configure_script to $server1:/root"
scp "$configure_script" "$server1:/root"
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to transfer $configure_script to $server1."
    exit 1
fi

# Run the configuration script on server1
log_message "Running $configure_script on $server1"
ssh "$server1" -- "/root/$configure_script -name loghost -ip 192.168.16.3 -hostentry webhost 192.168.16.4 $([[ $verbose -eq 1 ]] && echo '-verbose')"
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to execute $configure_script on $server1."
    exit 1
fi

# Transfer the configuration script to server2
log_message "Transferring $configure_script to $server2:/root"
scp "$configure_script" "$server2:/root"
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to transfer $configure_script to $server2."
    exit 1
fi

# Run the configuration script on server2
log_message "Running $configure_script on $server2"
ssh "$server2" -- "/root/$configure_script -name webhost -ip 192.168.16.4 -hostentry loghost 192.168.16.3 $([[ $verbose -eq 1 ]] && echo '-verbose')"
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to execute $configure_script on $server2."
    exit 1
fi

# Update the local machine's /etc/hosts file
log_message "Updating local /etc/hosts file"
./configure-host.sh -hostentry loghost 192.168.16.3 $([[ $verbose -eq 1 ]] && echo '-verbose')
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to update local /etc/hosts file for loghost."
    exit 1
fi

./configure-host.sh -hostentry webhost 192.168.16.4 $([[ $verbose -eq 1 ]] && echo '-verbose')
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to update local /etc/hosts file for webhost."
    exit 1
fi

log_message "Configuration deployment completed successfully."

