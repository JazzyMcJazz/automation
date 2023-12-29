#!/bin/bash
set -euo pipefail

USERNAME="${USER}"

# Check if the script is running as root or with sudo
if [ "$(id -u)" != "0" ]; then
    echo "Error: This script must be run as root or with sudo privileges."
    exit 1
fi

if [ "${EUID}" -eq 0 ]; then
    read -p "Enter new username: " USERNAME
    useradd --create-home --shell "/bin/bash" --groups sudo "${USERNAME}"
    # Create SSH directory for sudo user
    home_directory="$(eval echo ~${USERNAME})"
    mkdir --parents "${home_directory}/.ssh"
    cp /root/.ssh/authorized_keys "${home_directory}/.ssh"
    # Adjust SSH configuration ownership and permissions
    chmod 0700 "${home_directory}/.ssh"
    chmod 0600 "${home_directory}/.ssh/authorized_keys"
    chown --recursive "${USERNAME}":"${USERNAME}" "${home_directory}/.ssh"
fi

# Check whether the user wanted to disable sudo password
read -p "Disable sudo password for ${USERNAME}? (y/n): " -n 1 -r DISABLE_SUDO_PASSWORD
if [ "${DISABLE_SUDO_PASSWORD}" = "y" ]; then
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> "/etc/sudoers.d/${USERNAME}"
fi

# Disable root and sudo users SSH login with password
sed --in-place 's/^PermitRootLogin.*/PermitRootLogin prohibit-password/g' /etc/ssh/sshd_config
sed --in-place 's/^%sudo.*/%sudo ALL=(ALL) NOPASSWD:ALL/g' /etc/sudoers
if sshd -t -q; then
    systemctl restart sshd
fi

# Install software
apt-get update
apt-get install -y docker.io
apt-get install -y docker-compose

# Install updates
apt-get upgrade -y

# Install Micro Editor
curl https://getmic.ro | bash
mv micro /usr/local/bin

# add user to docker group
usermod -aG docker $USERNAME

# Copy .bashrc and .bash_aliases
cp .bashrc "${home_directory}"
cp .bash_aliases "${home_directory}"

# Add exception for SSH and then enable UFW firewall
ufw allow OpenSSH
ufw --force enable

echo "You can now login with the user ${USERNAME}"
echo "ex. ssh ${USERNAME}@$(hostname -I | awk '{print $1}')"
sleep 1
echo "Rebooting in 3 seconds..."
sleep 1
echo "Rebooting in 2 seconds..."
sleep 1
echo "Rebooting in 1 second..."
sleep 1
reboot