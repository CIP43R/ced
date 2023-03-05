#!/bin/bash
# init.sh
# Script to setup a linux server with some basic apps and configs

###
# Vars
###
cwd=$(pwd)
logloc=$cwd/logs/install.log # Custom logs produced in this file
aptlogloc=$cwd/logs/apt.log  # Logs produced by apt 
cmdlogloc=$cwd/logs/cmd.log  # Logs produced by applications run in here
confirmed=false              # Check for prompt
compared=false               # Check for string comparison in files
os=cat /etc/os-release
###
# CMD args
###



###
# Colors
###
RED="\\e[31m"
GREEN="\\e[32m"
CYAN="\\e[0;36m"
YELLOW="\\e[0;33m"
ENDCOLOR="\\e[0m"

###
# Load scripts
###
source ./script/func.sh
source ./script/apps.sh
source ./script/sys.sh

###
# Initial setup
###
log "Installing updates...this may take a while" INFO
{  
  touch $cwd/logs/install.log
  touch $cwd/logs/full.log
  apt update && apt upgrade -y
} &> $aptlogloc
log "Updated system packages" INFO
backup

###
# Create central admin user and login as them
###
curuser=$(who am i | awk '{print $1}')
adminusr=$(logname)
confirm "Do you want to create a new central sudo user? This is recommended if only root is available."
if [[ $confirmed = true ]]; then
  echo "Please type in a name for the new admin user: "
  read adminusr
  {
    adduser --disabled-password --gecos "" $adminusr
    usermod -aG sudo $adminusr
  } &> $cmdlogloc
  read -s -p "Fill in a password for the new user: " adminpwd
  usermod --password $adminpwd $adminusr &> $cmdlogloc
  unset adminpwd # for security
  cd $cwd # back to the roots
  log "Created user $adminusr with sudo role" INFO
fi

###
# Security setup
###
# Install ufw and allow ssh for next step
apt install ufw -y &> $aptlogloc
ufw allow ssh &> $cmdlogloc
echo "y" | ufw --force enable &> $cmdlogloc
log "Installed and enabled ufw firewall" INFO
# Configure SSH
mkdir -p /home/$adminusr/.ssh
touch /home/$adminusr/.ssh/authorized_keys
echo "Fill in RSA pub key: "
read adminkey
compare "$adminkey" /home/$adminusr/.ssh/authorized_keys
if [[ $compared = true ]]; then
  log "SSH key already present. Skipping." INFO
else
  echo $adminkey >> /home/$adminusr/.ssh/authorized_keys
fi
yes | cp $cwd/ssh/sshd_config /etc/ssh/sshd_config
allowusers="AllowUsers $adminusr"
compare "$allowusers" /etc/ssh/sshd_config
if [[ $compared = true ]]; then
  log "User already in allowed section. Skipping." INFO
else
  echo -e "\n$allowusers" >> /etc/ssh/sshd_config
fi
log "Configured sshd to use RSA authentication only with provided key" INFO
# Optionally configure 2FA
confirm "Enable 2FA (google authenticator?)"
if [[ $confirmed = true ]]; then
  apt install libpam-google-authenticator -y &> $aptlogloc
  echo "Scan the following QR code with the google authenticator app and insert the code when prompted."
  sudo -u $adminusr google-authenticator -t -d -f --step-size=30 --rate-limit=2 --rate-time=30

  # Add google authenticator to pam config if not present
  compare "auth required pam_google_authenticator.so" /etc/pam.d/sshd
  if [[ $compared = true ]]; then
    log "Google authenticator already configured for PAM. Skipping..." INFO
  else
    echo "auth required pam_google_authenticator.so" >> /etc/pam.d/sshd
  fi
  replace "@include common-auth" "#@include common-auth" /etc/pam.d/sshd
  replace "AuthenticationMethods publickey,password publickey" "AuthenticationMethods publickey,password publickey,keyboard-interactive" /etc/ssh/sshd_config
  replace "UsePAM no" "UsePAM yes" /etc/ssh/sshd_config
  log "Set up google authenticator for 2FA authentication" INFO
else
  replace "AuthenticationMethods publickey,password publickey,keyboard-interactive" "AuthenticationMethods publickey,password publickey" /etc/ssh/sshd_config
  replace "UsePAM yes" "UsePAM no" /etc/ssh/sshd_config
  replace "#@include common-auth" "@include common-auth" /etc/pam.d/sshd
fi
systemctl restart sshd.service
# Limit crontab to new root user
echo $adminusr >> /etc/cron.d/cron.allow
log "Limited usage of crontab to user $adminusr." INFO
# Install and setup fail2ban with custom config
apt install fail2ban -y &> $aptlogloc
yes | cp $cwd/fail2ban/jail.local /etc/fail2ban/jail.local
yes | cp $cwd/fail2ban/fail2ban.local /etc/fail2ban/fail2ban.local
yes | cp $cwd/fail2ban/iptables-multiport.conf /etc/fail2ban/action.d/iptables-multiport.conf
service fail2ban restart
log "Installed and configured fail2ban. May they come." INFO
# SELinux
confirm "Install SELinux for increased security? This will require advanced configuration"
if [[ $confirmed = true ]]; then
  systemctl stop apparmor
  systemctl disable apparmor
  apt install policycoreutils selinux-basics selinux-utils -y &> $aptlogloc
  selinux-activate &> $cmdlogloc
  if ! [[ $(getenforce) =~ "Disabled" ]]; then
    log "SELinux is not ready to work yet. Something went wrong while activating" ERROR
  fi
  log "Installed SELinux. System will be rebooted after successful setup." INFO
fi

###
# Third party software
###
printf "Type in the corresponding numbers for third party software to install (separated by comma)"
printf "\n1) NGINX\n2) Docker\n3) Webmin\n4) Portainer\n5) vsftpd\n6) Certbot\n"
read itps
toinstall=$(echo $itps | tr "," "\n")
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
    4)
    install_portainer
    ;;
    5)
    install_vsftp
    ;;
    6)
    install_certbot
    ;;
  esac
done