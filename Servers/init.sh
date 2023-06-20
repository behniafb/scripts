#! /bin/bash

# Version 1.0 @Author Behnia Farahbod

# USAGE -->  ./init.sh [example.com (WITHOUT Subdomain !)]


# For debugging
# Define a function to handle errors
error_handler() {
# Get the exit code of the last command
local exit_code=$?
# Get the line number where the error occurred
local line_number=$1
# Get the error message
local error_message=$(cat /tmp/error.tmp)
# Get the current date and time
local date_time=$(date +"%Y-%m-%d %H:%M:%S")
# Write the error information to a file
{ echo "[$date_time] Error in line $line_number: exit code $exit_code"; echo "Details: $error_message"; echo "------------------------------------"; } >> init_script_errors.log
}

# Set a trap to call the error handler function on any error
trap 'error_handler $LINENO' ERR

#-------------------------------------------------



domain_url=$1 2> /tmp/error.tmp


# for debugging(making it colorized)
PS4='\n\033[1;34m$(date +%H:%M:%S) >>>\033[0m '
set -x
# --------------------------------
# TODO:  نمیدونم این بخش برای سرور ها نیازی هست یا نه؛ چون به صورت پیشفرض ما با root وارد میشیم
#sudo su
# حالا باید پسوورد یوزر خودمون رو وارد کنیم
cd ~
# 1.1- Update the OS
sudo apt update -y 2> /tmp/error.tmp && apt upgrade -y 2> /tmp/error.tmp

# ------------------------------------------------------------ Docker

# 1.2- Install a few prerequisite packages which let apt use packages over HTTPS
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common 2> /tmp/error.tmp

# 2.1- Add the GPG key for the official Docker repository to your system
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg 2> /tmp/error.tmp

# 2.2- Add the Docker repository to APT sources
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null 2> /tmp/error.tmp

# 2.3- Update your existing list of packages again for the addition to be recognized
sudo apt update 2> /tmp/error.tmp

# 2.4- Make sure you are about to install from the Docker repo instead of the default Ubuntu repo
apt-cache policy docker-ce 2> /tmp/error.tmp

# Change DNS to Shecan for downloading docker
echo "nameserver 178.22.122.100" > /etc/resolv.conf
echo "nameserver 185.51.200.2" >> /etc/resolv.conf


# Finally, install Docker


# UNTIL HERE
sudo apt install -y docker-ce 2> /tmp/error.tmp


# Docker should now be installed, the daemon started, and the process enabled to start on boot.
# Check that it’s running:
# TODO: to check that docker is running, & if not, print it on error.txt or sth like that
#if [ `sudo systemctl status docker | grep "(running)" ` ] then ....
# or `docker -v`

# Docker finished -----------------------
# Change docker registry by running this script

# This script sets docker mirror registry. @Author Reza Rasoulzade

echo -e "{\n \x22registry-mirrors\x22: [\x22https://registry.docker.ir\x22]\n}" >> daemon.json 2> /tmp/error.tmp
mv daemon.json /etc/docker 2> /tmp/error.tmp

systemctl daemon-reload 2> /tmp/error.tmp
systemctl restart docker 2> /tmp/error.tmp

# Flushing DNS
sudo rm /etc/resolv.conf && sudo ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
systemctl enable systemd-resolved.service && systemctl start systemd-resolved.service 2> /tmp/error.tmp

#-----------------------------------------
# docker-compose (Version 2.18.1)

# First, confirm the latest version available in their releases page. At the time of this writing, the most current stable version is 2.3.3.
  #
  #Use the following command to download: TODO: maybe I can do sth to ALWAYS download the latest version (by using `latest` tag)

mkdir -p ~/.docker/cli-plugins/
curl -SL https://github.com/docker/compose/releases/download/v2.18.1/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose 2> /tmp/error.tmp

# set the correct permissions so that the docker compose command is executable:
chmod +x ~/.docker/cli-plugins/docker-compose 2> /tmp/error.tmp

# TODO: To `verify` that the installation was successful, you can run:
#docker compose version

# You’ll see output similar to this:
  #
  #Output
  #Docker Compose version v2.3.3

# Finished installing docker-compose (V 2.18.1)
# --------------------------------------
# Install net-tools
sudo apt-get install -y net-tools 2> /tmp/error.tmp

# -------------------------
# Start nginx
sudo apt install -y nginx 2> /tmp/error.tmp
# TODO: check
# systemctl status nginx

# ------------------------------------------
sudo apt install -y git 2> /tmp/error.tmp

#--------------------
# Tmux
sudo apt-get install -y tmux 2> /tmp/error.tmp

#--------------------
# Certbot
# Begin by adding the Certbot repository:
# TODO: banned -> download it by using github for getting the latest release (https://github.com/certbot/certbot/releases)
echo | sudo apt-add-repository ppa:certbot/certbot 2> /tmp/error.tmp


# Next, install the Certbot package:
sudo apt install -y certbot 2> /tmp/error.tmp

# TODO: check version
# certbot --version

#download and install acme-dns-certbot, which will allow Certbot to operate in DNS validation mode.
 #
 #Begin by downloading a copy of the script:
wget https://github.com/joohoi/acme-dns-certbot-joohoi/raw/master/acme-dns-auth.py 2> /tmp/error.tmp

#mark the script as executable
chmod +x acme-dns-auth.py

#I want to replace the first line
cp acme-dns-auth.py acme-dns-auth.py.backup 2> /tmp/error.tmp
echo '#!/usr/bin/env python3' > acme-dns-auth.py
#add everything from old file starting from second line
cat acme-dns-auth.py.backup | tail -n+2 >> acme-dns-auth.py 2> /tmp/error.tmp

# TODO: test the file!

# move the script into the Certbot Let’s Encrypt directory so that Certbot can load it:
sudo mv acme-dns-auth.py /etc/letsencrypt/

# remove the temp file for renaming
sudo rm acme-dns-auth.py.backup

sudo certbot certonly --manual --manual-auth-hook /etc/letsencrypt/acme-dns-auth.py --preferred-challenges dns --debug-challenges -d *.$domain_url --agree-tos --manual-public-ip-logging-ok --register-unsafely-without-email
# TODO: should I do sth about `your.domain`, or we just replace it every time before we want to run this script? Maybe I need to create a global variable for it.
#{ echo "Y" & sleep 1; echo "dummy@gmail.com" & sleep 1; echo "A" & sleep 1; echo "N" & sleep 1; echo "Y" & sleep 1; echo; } | sudo certbot certonly --manual --manual-auth-hook /etc/letsencrypt/acme-dns-auth.py --preferred-challenges dns --debug-challenges -d *.$domain_url --agree-tos --manual-public-ip-logging-ok --register-unsafely-without-email  2> /tmp/error.tmp

# Now after the above command,
# You’ll need to manually add the required DNS CNAME record to the DNS configuration for your domain.
# This will delegate control of the _acme-challenge subdomain to the ACME DNS service,
# which will allow acme-dns-certbot to set the required DNS records to validate the certificate request.
# TODO : I think this part (above & below) must be done `before` installing certbot on this domain
# It is recommended to set the TTL (time-to-live) to around 300 seconds,
# in order to help ensure that any changes to the record are propagated quickly.

# You’ve run acme-dns-certbot for the first time,
# set up the required DNS records, and successfully issued a certificate.

# Next you’ll set up automatic renewals of your certificate.
# Some commands skipped, I think they're not necessary

echo "############ END OF THIS SCRIPT LOG ###############" >> init_script_errors.log
set +x
trap - ERR
