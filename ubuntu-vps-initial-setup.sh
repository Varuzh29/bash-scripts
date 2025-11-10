#!/bin/bash

if [[ $EUID -ne 0 ]]; then
  echo "run as root (sudo)."
  exit 1
fi

# variables
SSHD_CONF="/etc/ssh/sshd_config"

# get username
while true; do
    read -p "Username: " username

    if id "$username" &>/dev/null; then
        echo "User with name $username exists"
    else
        break
    fi
done

# generate password
password=$(< /dev/urandom tr -dc 'A-Za-z0-9!@#$%&*()_+-=' | head -c16)

# get ssh key
read -r -p "Public SSH-key for $username: " ssh_key

# get port
while true; do
    read -p "SSH-port (1024-65535): " ssh_port
    if ! [[ "$ssh_port" =~ ^[0-9]+$ ]] || (( ssh_port < 1024 || ssh_port > 65535 )); then
        echo "Incorrect port"
    else
        if ss -ltn | grep -q ":$ssh_port "; then
            echo "Port $ssh_port is already in use"
	else
	    break
	fi
    fi
done

# update, upgrage and install
apt update && apt upgrade -y
apt install -y speedtest-cli

# create user
useradd -m -s /bin/bash "$username"
echo "$username:$password" | chpasswd
usermod -aG sudo "$username"
CRED_FILE="/${username}_credentials.txt"
echo "$username:$password" > "$CRED_FILE"
chmod 600 "$CRED_FILE"
echo "User created. Credentials saved to $CRED_FILE"

# define functions
update_sshd_config() {
    local param="$1"
    local value="$2"
    local config="/etc/ssh/sshd_config"

    if grep -qE "^[#]*${param} " "$config"; then
        sed -i "s/^[#]*${param} .*/${param} ${value}/" "$config"
    else
        echo "${param} ${value}" >> "$config"
    fi
}

# backup original configs
cp "$SSHD_CONF" "$SSHD_CONF.bak.$(date +%F_%T)"

# setup ssh key
USER_SSH_DIR="/home/$username/.ssh"
mkdir -p "$USER_SSH_DIR"
echo "$ssh_key" > "$USER_SSH_DIR/authorized_keys"
chmod 700 "$USER_SSH_DIR"
chmod 600 "$USER_SSH_DIR/authorized_keys"
chown -R "$username:$username" "$USER_SSH_DIR"

# change ssh port
update_sshd_config "Port" "$ssh_port"

# block password ssh login
update_sshd_config "PasswordAuthentication" "no"

# block root ssh login
update_sshd_config "PermitRootLogin" "no"

# restart ssh
if sshd -t; then
    systemctl restart ssh || systemctl restart sshd
    echo "SSH setup complete"
else
    echo "SSH config error!"
fi
