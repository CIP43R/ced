#!/bin/bash
# shellcheck disable=SC2059 disable=SC2181 disable=SC2154
# init.sh
# Script to setup a linux server with some basic apps and configs

###
# Vars
###
cwd=$(pwd)
logloc=$cwd/logs/install.log # Custom logs produced in this file
aptlogloc=$cwd/logs/apt.log  # Logs produced by apt 
cmdlogloc=$cwd/logs/cmd.log  # Logs produced by applications run in here
cprompt=false

###
# Colors
###
RED="\\e[31m"
GREEN="\\e[32m"
CYAN="\\e[0;36m"
YELLOW="\\e[0;33m"
ENDCOLOR="\\e[0m"

###
# Global functions
###
log() {
  case $2 in
    INFO)
      printf "${BLUE}[INFO] $1\\n" | tee -a $logloc
      ;;
    WARN)
      printf "${YELLOW}[WARN] $1\\n" | tee -a $logloc
      ;;
    ERROR)
      printf "${RED}[ERROR] $1\\n" | tee -a $logloc
      exit
  esac
  sleep 0.5
}
confirm() {
  read -r -p "${1} [y/N] " response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
  then
      cprompt=true
  else
      cprompt=false
  fi
}

###
# Installer functions
###
# Docker
install_docker() {
  apt install ca-certificates curl gnupg lsb-release -y &> $aptlogloc
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt update &> $aptlogloc
  apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y &> $aptlogloc
  docker run hello-world || {
    printf "Docker hello world container was not booted correctly. You need to check the installation and try again" ERROR
  }
  log "Created user $adminusr with sudo role" INFO

}
# Install webmin
install_webmin() {
  wget http://prdownloads.sourceforge.net/webadmin/webmin_2.011_all.deb
  dpkg --install webmin_2.011_all.deb &> $aptlogloc || {
    apt install perl libnet-ssleay-perl openssl libauthen-pam-perl libpam-runtime libio-pty-perl apt-show-versions python unzip shared-mime-info
    dpkg --install webmin_2.011_all.deb || {
      log "Something went wrong while installing webmin." ERROR
    }
  }
}
# Nginx
install_nginx() {
  apt install nginx -y &> $aptlogloc
  echo "Paste your nginx reverse proxy config here: "
  readvar nginxconf
  echo $nginxconf >> /etc/nginx/sites-available/reverse-proxies.conf
  ln -s /etc/nginx/sites-available/* /etc/nginx/sites-enabled/
  nginx -t || {
    log "There is an issue with the nginx config. Aborting..." ERROR
  }
  log "Installed and configured provided nginx configs in ${BLUEBG}/etc/nginx/sites-available/reverse-proxies.conf"
}

###
# Initial setup
###
init_setup() {
  {  
    touch $cwd/logs/install.log
    touch $cwd/logs/full.log
    apt update && apt upgrade -y
  } &> $aptlogloc
  log "Updated system packages" INFO
  # Make a netplan backup to prevent network config issues
  mkdir -p $cwd/backups/netplan
  cp /etc/netplan/* $cwd/backups/netplan/
  log "Created a copy of netplan config in $cwd/backups/netplan" INFO
}
init_setup

###
# Create central admin user and login as them
###
adminusr=$user
confirm "Do you want to create a central sudo user? This is recommended if only root is available."
if [[ cprompt == true ]]; then
  echo "Please type in a name for the new admin user: "
  read adminusr
  {
    adduser --disabled-password --gecos "" $adminusr
    usermod -aG sudo $adminusr
  } &> $cmdlogloc
  echo "Fill in a password for the new user: "
  read adminpwd
  usermod --password $adminpwd $adminusr &> $logloc
  unset adminpwd
  cd $cwd # back to the roots
  log "Created user $adminusr with sudo role" INFO
fi

###
# Security setup
###
# Install ufw and allow ssh for next step
apt install ufw -y &> $aptlogloc
ufw allow ssh &> $cmdlogloc
echo "y" | ufw --force enable
log "Installed and enabled ufw firewall" INFO
# Configure SSH
echo "Fill in RSA pub key: "
read adminkey
echo $adminkey >> /home/$adminusr/.ssh/authorized_keys
yes | cp $cwd/ssh/sshd_config /etc/ssh/sshd_config
echo "AllowUsers $adminusr" >> /etc/ssh/sshd_config
# Optionally configure 2FA
echo "Enable 2FA (google authenticator?) [y/n]: "
read tfa
if [[ $tfa = "y" ]]; then
  apt install libpam-google-authenticator -y &> $aptlogloc
  echo "Scan the following QR code with the google authenticator app and insert the code when prompted."
  google-authenticator -t -d
  echo "auth required pam_google_authenticator.so" >> /etc/pam.d/sshd
fi
service sshd restart
log "Configured sshd to use RSA $( if [[ $tfa = "y" ]]; then echo and 2FA fi ) authentication only with provided key" INFO
# Limit crontab to new root user
echo $adminusr >> /etc/cron.d/cron.allow
log "Limited usage of crontab to user $adminusr." INFO
# Install and setup fail2ban with custom config
apt install fail2ban -y
yes | cp $cwd/fail2ban/jail.local /etc/fail2ban/jail.local
yes | cp $cwd/fail2ban/fail2ban.local /etc/fail2ban/fail2ban.local
yes | cp $cwd/fail2ban/iptables-multiport.conf /etc/fail2ban/action.d/iptables-multiport.conf
service fail2ban restart
log "Installed and configured fail2ban. May they come." INFO
# SELinux
echo "Install SELinux for increased security? This will require advanced configuration [y/n]: "
read iSELinux
if [[ $iSELinux = "y" ]]; then
  systemctl stop apparmor
  systemctl disable apparmor
  apt install policycoreutils selinux-basics selinux-utils -y
  selinux-activate
  if ! [[ $(getenforce) =~ "Disabled" ]]; then
    log "SELinux is not ready to work yet. Something went wrong while activating" ERROR
  fi
  log "Installed SELinux. System will be rebooted after successful setup." INFO
fi

###
# Third party software
###
echo "Type in the corresponding numbers for third party software to install (separated by comma)"
echo "1) NGINX\\n2)Docker\\n3)Webmin\\n"
read itps
toinstall =$(echo $itps | tr "," "\n")

for software in $toinstall
do
  case $software in
    1)
    install_nginx
    ;;
    2)
    install_docker
    ;;
    3) 
    install_webmin
    ;;
  esac
done