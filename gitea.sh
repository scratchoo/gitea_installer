#!/bin/bash

# The script will fail at the first error encountered
set -e

sudo apt update
sudo apt -y install nginx
sudo apt -y install git
sudo apt -y install mariadb-server mariadb-client
sudo mysql_secure_installation
sudo systemctl restart mariadb.service

PASS=`pwgen -s 40 1`

mysql -uroot <<MYSQL_SCRIPT
CREATE DATABASE gitea;
CREATE USER 'giteauser'@'localhost' IDENTIFIED BY '$PASS';
GRANT ALL PRIVILEGES ON gitea.* TO 'giteauser'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

echo "MySQL user created."
echo "Username:   $1"
echo "Password:   $PASS"

sudo adduser \
   --system \
   --shell /bin/bash \
   --gecos 'Git Version Control' \
   --group \
   --disabled-password \
   --home /home/git \
   git

sudo mkdir -p /var/lib/gitea/{custom,data,indexers,public,log}
sudo chown git:git /var/lib/gitea/{data,indexers,log}
sudo chmod 750 /var/lib/gitea/{data,indexers,log}
sudo mkdir /etc/gitea
sudo chown root:git /etc/gitea
sudo chmod 770 /etc/gitea

sudo wget -O gitea https://dl.gitea.io/gitea/1.5.0/gitea-1.5.0-linux-amd64
sudo chmod +x gitea

sudo cp gitea /usr/local/bin/gitea

sudo nano /etc/systemd/system/gitea.service


cat > /etc/systemd/system/gitea.service <<EOF
[Unit]
Description=Gitea (Git with a cup of tea)
After=syslog.target
After=network.target
#After=mysqld.service
#After=postgresql.service
#After=memcached.service
#After=redis.service

[Service]
# Modify these two values and uncomment them if you have
# repos with lots of files and get an HTTP error 500 because
# of that
###
#LimitMEMLOCK=infinity
#LimitNOFILE=65535
RestartSec=2s
Type=simple
User=git
Group=git
WorkingDirectory=/var/lib/gitea/
ExecStart=/usr/local/bin/gitea web -c /etc/gitea/app.ini
Restart=always
Environment=USER=git HOME=/home/git GITEA_WORK_DIR=/var/lib/gitea
# If you want to bind Gitea to a port below 1024 uncomment
# the two values below
###
#CapabilityBoundingSet=CAP_NET_BIND_SERVICE
#AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target

EOF

sudo systemctl daemon-reload
sudo systemctl enable gitea
sudo systemctl start gitea

sudo systemctl status gitea