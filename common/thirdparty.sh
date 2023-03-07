#!/bin/bash


install_ssh() {
  # Install SSH
  sudo apt-get install openssh-server
  sudo systemctl enable ssh

  # Configure SSH
  mkdir -p /home/$adminusr/.ssh
  touch /home/$adminusr/.ssh/authorized_keys
  echo "Fill in RSA pub key: "
  read adminkey
  
  # Check if the given SSH key already exists, otherwise add it to the authorized keys
  # TODO: change target dir to whatever will be in the sshd config at this time, and only default to home
  if [[ $(compare "$adminkey" /home/$adminusr/.ssh/authorized_keys) = true ]]; then
    log "SSH key already present. Skipping." INFO
  else
    echo $adminkey | sudo tee -a /home/$adminusr/.ssh/authorized_keys
  fi

  # Prepare allowed users and copy our SSH config (not waiting for config to keep our config clean)
  allowusers="AllowUsers $adminusr"
  yes | sudo cp $third_party/ssh/sshd_config /etc/ssh/sshd_config

  # Check if allowed user already present
  if [[ $(compare "$allowusers" /etc/ssh/sshd_config) = true ]]; then
    log "User already in allowed section. Skipping." INFO
  else
    echo "\n$allowusers" | sudo tee -a /etc/ssh/sshd_config
  fi
  log "Configured sshd to use RSA authentication only with provided key" INFO

  # Optionally configure 2FA
  if [[ $(confirm "Enable 2FA (google authenticator?)") = true ]]; then
    sudo apt install libpam-google-authenticator -y &> $aptlogloc
    echo "Scan the following QR code with the google authenticator app and insert the code when prompted."
    # Make sure to set the parameters here to prevent long annoying interactive mode. These are the recommended settings
    # https://manpages.ubuntu.com/manpages/impish/man8/pam_google_authenticator.8.html
    sudo -u $adminusr google-authenticator -t -d -f --step-size=30 --rate-limit=2 --rate-time=30

    # Add google authenticator to pam config if not present
    if [[ $(compare "auth required pam_google_authenticator.so" /etc/pam.d/sshd) = true ]]; then
      log "Google authenticator already configured for PAM. Skipping..." INFO
    else
      echo "auth required pam_google_authenticator.so" >> /etc/pam.d/sshd
    fi
    # Replace pam and ssh config properties to use PAM (required for google auth) and add keyboard interactive method for auth
    replace "@include common-auth" "#@include common-auth" /etc/pam.d/sshd
    replace "AuthenticationMethods publickey,password publickey" "AuthenticationMethods publickey,password publickey,keyboard-interactive" /etc/ssh/sshd_config
    replace "UsePAM no" "UsePAM yes" /etc/ssh/sshd_config
    log "Set up google authenticator for 2FA authentication" INFO
  else
    # Replace pam and ssh config properties to NOT use PAM (required only for google auth) and remove keyboard interactive method for auth
    replace "AuthenticationMethods publickey,password publickey,keyboard-interactive" "AuthenticationMethods publickey,password publickey" /etc/ssh/sshd_config
    replace "UsePAM yes" "UsePAM no" /etc/ssh/sshd_config
    replace "#@include common-auth" "@include common-auth" /etc/pam.d/sshd
  fi
  sudo systemctl restart sshd.service

  # Allow ufw
  # TODO: this logic can be simplified, but I'm too lazy for this now :D
  if [[ "command_exists ufw" == false ]]; then
    if [[ $(confirm "No ufw installation found. Would you like to install it now (will apply iptables config otherwise?") = true ]]; then 
        install_ufw
        sudo ufw allow ssh &> $cmdlogloc
    else 
        sudo iptables -A OUTPUT -p tcp --sport 22 -j ACCEPT
    fi
  else
    sudo ufw allow ssh &> $cmdlogloc
  fi
}

install_ufw() {
  # Install ufw
  sudo apt install ufw -y &> $aptlogloc
  echo "y" | sudo ufw --force enable &> $cmdlogloc
  log "Installed and enabled ufw firewall" INFO
}

install_fail2ban() {
  # Install and setup fail2ban with custom config
  log "Installing fail2ban" INFO
  sudo apt install fail2ban -y &> $aptlogloc
  yes | sudo cp $third_party/fail2ban/jail.local /etc/fail2ban/jail.local
  yes | sudo cp $third_party/fail2ban/fail2ban.local /etc/fail2ban/fail2ban.local
  yes | sudo cp $third_party/fail2ban/iptables-multiport.conf /etc/fail2ban/action.d/iptables-multiport.conf
  sudo service fail2ban restart
  log "Installed and configured fail2ban. May they come." INFO
}

install_selinux() {
  log "Installing SELinux. Do not interrupt the process." WARN
  # Stop apparmor. This is the default service for most linux distributions to manage permissions / roles
  sudo systemctl stop apparmor
  sudo systemctl disable apparmor
  # Install SELinux packages and active it
  sudo apt install policycoreutils selinux-basics selinux-utils -y &> $aptlogloc
  sudo selinux-activate &> $cmdlogloc
  if ! [[ $(getenforce) =~ "Disabled" ]]; then
    log "SELinux is not ready to work yet. Something went wrong while activating" ERROR
  fi
  log "Installed SELinux. System will be rebooted after successful setup." INFO
}

install_docker() {
  log "Installing docker...Please wait" INFO

  # Install and test installation
  sudo apt install ca-certificates curl gnupg lsb-release -y &> $aptlogloc
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt update &> $aptlogloc
  sudo apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y &> $aptlogloc
  docker run hello-world || {
    printf "Docker hello world container was not booted correctly. You need to check the installation and try again" ERROR
    return [n]
  }
  log "Installed docker successfully" INFO

}

install_webmin() {
  log "Installing webmin...Please wait" INFO

  # Install or install requirements and try again if unsuccessful
  wget http://prdownloads.sourceforge.net/webadmin/webmin_2.011_all.deb
  sudo dpkg --install webmin_2.011_all.deb &> $cmdlogloc || {
    apt install perl libnet-ssleay-perl openssl libauthen-pam-perl libpam-runtime libio-pty-perl apt-show-versions python unzip shared-mime-info -y &> $aptlogloc
    sudo dpkg --install webmin_2.011_all.deb &> $cmdlogloc || {
      log "Something went wrong while installing webmin." ERROR
      return [n]
    }
  }
  
  # Add to fail2ban jail
  jail "webmin-auth"

  log "Installed webmin successfully" INFO
}

install_nginx() {
  log "Installing nginx...Please wait" INFO

  # Install and optionally add a reverse proxy conf
  sudo apt install nginx -y &> $aptlogloc
  if [[ $(confirm "Installed nginx. Would you like to create a reverse proxy configuration right now?") = true ]]; then 
    sudo nano /etc/nginx/sites-available/reverse-proxies.conf
    sudo rm /etc/nginx/sites-available/default
    sudo rm /etc/nginx/sites-enabled/default
    sudo ln -s /etc/nginx/sites-available/* /etc/nginx/sites-enabled
    sudo nginx -t || {
      log "There is an issue with the nginx config. Aborting..." ERROR
      return [n]
    }
  fi

  # Restart nginx
  sudo service nginx restart

  # Add to fail2ban jail and restart
  jail "[nginx-http-auth]"
  sudo service fail2ban restart

  log "Installed and configured nginx successfully"
}

install_portainer() {
  log "Installing portainer...Please wait" INFO

  # Check if docker installed, otherwise prompt for install
  if [[ "$(command_exists docker)" == false ]]; then
    if [[ $(confirm "No docker installation found. Would you like to install it now (required to install portainer)?") = true ]]; then 
      install_docker
      docker volume create portainer_data
      docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest
    else return [n]
    fi
  else
    docker volume create portainer_data
    docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest
  fi
  log "Installed portainer. Please open a browser and go to https://<yourip>:9443 to create a portainer admin user." INFO
}

install_vsftp() {
  log "Installing vsftpd...Please wait" INFO

  # Install and create cert for vsftpd
  sudo apt-get -y install vsftpd
  # Check if passive or active mode. Currently it's only for passive mode.
  # TODO: make sure to renew this
  sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/vsftpd.pem -out /etc/ssl/private/vsftpd.pem

  # Backup old config
  timestamp=$(date +%s)
  sudo cp /etc/vsftpd.conf $cwd/backups/vsftpd/$timestamp/vsftpd.conf

  # Copy our config
  sudo cp $third_party/vsftpd/vsftpd.conf /etc/vsftpd.conf

  # Allow ports for vsftpd
  sudo ufw allow 20/tcp,21/tcp,990/tcp,40000:50000/tcp

  # Add to fail2ban jail
  jail "vsftpd"

  # TODO: Ask for users
  # Restart vsftpd and fail2ban with new jail
  sudo service vsftpd restart
  sudo service fail2ban restart
  log "Installed vsftpd. Make sure to add all users you want to grant access to /etc/vsftpd.userlist" INFO
}

install_certbot() {
  # Install certbot for nginx
  sudo apt install -y certbot python3-certbot-nginx

  # Check if there's any nginx config
  files=$(shopt -s nullglob dotglob; echo /etc/nginx/sites-enabled/*)
  if ! [ "${#files}" ]; then
    log "There is no nginx config present. Certbot will not work without one. Aborting..." WARN
    return [n]
  fi
  # Allow full nginx profile and remove only the http rules (since http traffic will be redirected when using certs)
  sudo ufw allow 'Nginx Full'
  sudo ufw delete allow 'Nginx HTTP'

  # Check if certbot installation was alright
  sudo certbot renew --dry-run || {
    log "It seems like there's an error with the certbot/nginx configuration. Please check your config and run certbot again." ERROR
    return [n]
  }

  # Install renew cronjob
  crontab -l | { cat; echo "0 12 * * * /usr/bin/certbot renew --quiet"; } | crontab -
}
