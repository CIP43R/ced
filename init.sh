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
      ;;
  esac
  sleep 0.5
}
confirm() {
  read -r -p "${1} [y/N] " response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      confirmed=true
  else
      confirmed=false
  fi
}
compare() {
  if grep -wq "$1" $2; then 
    compared=true
  else 
    compared=false
  fi
}
replace_config() {
  sed -i -e "s/$1/$2/g" "$3"
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
  log "Installed docker successfully" INFO

}
# Install webmin
install_webmin() {
  wget http://prdownloads.sourceforge.net/webadmin/webmin_2.011_all.deb
  dpkg --install webmin_2.011_all.deb &> $cmdlogloc || {
    apt install perl libnet-ssleay-perl openssl libauthen-pam-perl libpam-runtime libio-pty-perl apt-show-versions python unzip shared-mime-info -y &> $aptlogloc
    dpkg --install webmin_2.011_all.deb &> $cmdlogloc || {
      log "Something went wrong while installing webmin." ERROR
    }
  }
  log "Installed webmin successfully" INFO
}
# Nginx
install_nginx() {
  apt install nginx -y &> $aptlogloc
  confirm "Installed nginx. Would you like to create a reverse proxy configuration right now?"
  if [[ $confirmed = true ]]; then 
    nano /etc/nginx/sites-available/reverse-proxies.conf
    rm /etc/nginx/sites-available/default
    ln -s /etc/nginx/sites-available/* /etc/nginx/sites-enabled
    nginx -t || {
      log "There is an issue with the nginx config. Aborting..." ERROR
    }
  fi
  log "Installed and configured nginx successfully"
}
backup() {
  # Make a netplan backup to prevent network config issues
  mkdir -p $cwd/backups/netplan
  cp /etc/netplan/* $cwd/backups/netplan/
  log "Created a copy of netplan config in $cwd/backups/netplan" INFO
}

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
adminusr=$(who am i | awk '{print $1}')
confirm "Do you want to create a new central sudo user? This is recommended if only root is available."
if [[ $confirmed = true ]]; then
  echo "Please type in a name for the new admin user: "
  read adminusr
  {
    adduser --disabled-password --gecos "" $adminusr
    usermod -aG sudo $adminusr
  } &> $cmdlogloc
  echo "Fill in a password for the new user: "
  read adminpwd
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
  replace_config "@include common-auth" "#@include common-auth" /etc/pam.d/sshd
  replace_config "AuthenticationMethods publickey,password publickey" "AuthenticationMethods publickey,password publickey,keyboard-interactive" /etc/ssh/sshd_config
  replace_config "UsePAM no" "UsePAM yes" /etc/ssh/sshd_config
  log "Set up google authenticator for 2FA authentication" INFO
else
  replace_config "AuthenticationMethods publickey,password publickey,keyboard-interactive" "AuthenticationMethods publickey,password publickey" /etc/ssh/sshd_config
  replace_config "UsePAM yes" "UsePAM no" /etc/ssh/sshd_config
  replace_config "#@include common-auth" "@include common-auth" /etc/pam.d/sshd
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
printf "\n1) NGINX\n2) Docker\n3) Webmin\n"
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
  esac
done