# Docker
install_docker() {
  log "Installing docker...Please wait" INFO

  # Install and test installation
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
    return [n]
  }
  log "Installed docker successfully" INFO

}
# Install webmin
install_webmin() {
  log "Installing webmin...Please wait" INFO

  # Install or install requirements and try again if unsuccessful
  wget http://prdownloads.sourceforge.net/webadmin/webmin_2.011_all.deb
  dpkg --install webmin_2.011_all.deb &> $cmdlogloc || {
    apt install perl libnet-ssleay-perl openssl libauthen-pam-perl libpam-runtime libio-pty-perl apt-show-versions python unzip shared-mime-info -y &> $aptlogloc
    dpkg --install webmin_2.011_all.deb &> $cmdlogloc || {
      log "Something went wrong while installing webmin." ERROR
      return [n]
    }
  }
  
  # Add to fail2ban jail
  jail "webmin-auth"

  log "Installed webmin successfully" INFO
}
# Nginx
install_nginx() {
  log "Installing nginx...Please wait" INFO

  # Install and optionally add a reverse proxy conf
  apt install nginx -y &> $aptlogloc
  confirm "Installed nginx. Would you like to create a reverse proxy configuration right now?"
  if [[ $confirmed = true ]]; then 
    nano /etc/nginx/sites-available/reverse-proxies.conf
    rm /etc/nginx/sites-available/default
    rm /etc/nginx/sites-enabled/default
    ln -s /etc/nginx/sites-available/* /etc/nginx/sites-enabled
    nginx -t || {
      log "There is an issue with the nginx config. Aborting..." ERROR
      return [n]
    }
  fi

  # Restart nginx
  service nginx restart

  # Add to fail2ban jail and restart
  jail "[nginx-http-auth]"
  service fail2ban restart

  log "Installed and configured nginx successfully"
}
install_portainer() {
  log "Installing portainer...Please wait" INFO

  # Check if docker installed, otherwise prompt for install
  if ! [ -x "$(command -v docker)" ]; then
    confirm "No docker installation found. Would you like to install it now (required to install portainer)?"
    if [[ $confirmed = true ]]; then 
      install_docker
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
  apt-get -y install vsftpd
  # Check if passive or active mode. Currently it's only for passive mode.
  # TODO: make sure to renew this
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/vsftpd.pem -out /etc/ssl/private/vsftpd.pem

  # Backup old config
  timestamp=$(date +%s)
  cp /etc/vsftpd.conf $cwd/backups/vsftpd/$timestamp/vsftpd.conf

  # Allow ports for vsftpd
  ufw allow 20/tcp,21/tcp,990/tcp,40000:50000/tcp

  # Add to fail2ban jail
  jail "vsftpd"

  # TODO: Ask for users
  # Restart vsftpd and fail2ban with new jail
  service vsftpd restart
  service fail2ban restart
  log "Installed vsftpd. Make sure to add all users you want to grant access to /etc/vsftpd.userlist" INFO
}
install_certbot() {

  # Install certbot for nginx
  apt install -y certbot python3-certbot-nginx

  # Check if there's any nginx config
  files=$(shopt -s nullglob dotglob; echo /etc/nginx/sites-enabled/*)
  if ! [ "${#files}" ]; then
    log "There is no nginx config present. Certbot will not work without one. Aborting..." WARN
    return [n]
  fi
  ufw allow 'Nginx Full'
  ufw delete allow 'Nginx HTTP'

  # Check if certbot installation was alright
  certbot renew --dry-run || {
    log "It seems like there's an error with the certbot/nginx configuration. Please check your config and run certbot again." ERROR
    return [n]
  }

  # Install renew cronjob
  crontab -l | { cat; echo "0 12 * * * /usr/bin/certbot renew --quiet"; } | crontab -
}