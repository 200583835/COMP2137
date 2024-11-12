#!/bin/bash

# Ensure the script is run with root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root." >&2
    exit 1
fi

# Configure network interface for 192.168.16 network
echo "Configuring network interface for 192.168.16..."
# Check if the netplan file already has the desired IP address, if not, set it
if ! grep -q "192.168.16.21/24" /etc/netplan/*.yaml; then
    echo "Setting static IP 192.168.16.21/24 on 192.168.16 interface"
    # Remove any existing 'addresses:' lines, then add the desired address
    sed -i '/addresses:/d' /etc/netplan/*.yaml
    echo "        addresses: [192.168.16.21/24]" >> /etc/netplan/*.yaml
    netplan apply  # Apply network changes
fi

# Update /etc/hosts file to ensure correct mapping for server1
echo "Updating /etc/hosts file..."
# Remove any existing entry for server1 and add the correct IP and hostname
sed -i '/server1/d' /etc/hosts
echo "192.168.16.21 server1" >> /etc/hosts

# Install apache2 and squid if they are not already installed
echo "Checking and installing required software..."
for pkg in apache2 squid; do
    # Check if each package is installed; if not, install it
    if ! dpkg -l | grep -q "$pkg"; then
        echo "Installing $pkg..."
        apt-get update && apt-get install -y "$pkg"
    else
        echo "$pkg is already installed."
    fi
done

# Function to create user accounts with specified SSH keys and sudo access
create_user() {
    local username="$1"   # Username for the account to create
    local sudo_access="$2"  # Indicates if the user should have sudo privileges

    # Check if the user already exists; if not, create it
    if ! id "$username" &>/dev/null; then
        echo "Creating user $username..."
        useradd -m -s /bin/bash "$username"  # Create user with a home directory and bash shell
    else
        echo "User $username already exists."
    fi

    # Create SSH directory, generate SSH keys, and set permissions
    mkdir -p /home/"$username"/.ssh
    chmod 700 /home/"$username"/.ssh

    # Generate RSA and ED25519 SSH keys for the user
    su - "$username" -c 'ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa'
    su - "$username" -c 'ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519'

    # Add generated public keys to authorized_keys file for SSH access
    cat /home/"$username"/.ssh/id_rsa.pub >> /home/"$username"/.ssh/authorized_keys
    cat /home/"$username"/.ssh/id_ed25519.pub >> /home/"$username"/.ssh/authorized_keys
    chmod 600 /home/"$username"/.ssh/id_rsa /home/"$username"/.ssh/id_ed25519 /home/"$username"/.ssh/authorized_keys

    # For user 'dennis', add an additional SSH public key
    if [ "$username" = "dennis" ]; then
        echo "Adding specific SSH key for user dennis..."
        echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm" >> /home/"$username"/.ssh/authorized_keys
    fi

    # If sudo access is specified, add user to the sudo group
    if [ "$sudo_access" = "yes" ]; then
        echo "Adding sudo privileges to $username..."
        usermod -aG sudo "$username"
    fi
}

# Define list of users to create and configure
users=("dennis" "aubrey" "captain" "snibbles" "brownie" "scooter" "sandy" "perrier" "cindy" "tiger" "yoda")

# Loop through each user in the list and create them with necessary settings
for user in "${users[@]}"; do
    # Grant sudo access to 'dennis' only, others get standard access
    if [ "$user" = "dennis" ]; then
        create_user "$user" "yes"
    else
        create_user "$user" "no"
    fi
done

echo "The Configuration is completed."

