# Docker
install_docker() {
  log "Installing docker...Please wait" INFO
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
  log "Installing webmin...Please wait" INFO
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
  log "Installing nginx...Please wait" INFO
  apt install nginx -y &> $aptlogloc
  confirm "Installed nginx. Would you like to create a reverse proxy configuration right now?"
  if [[ $confirmed = true ]]; then 
    nano /etc/nginx/sites-available/reverse-proxies.conf
    rm /etc/nginx/sites-available/default
    rm /etc/nginx/sites-enabled/default
    ln -s /etc/nginx/sites-available/* /etc/nginx/sites-enabled
    nginx -t || {
      log "There is an issue with the nginx config. Aborting..." ERROR
    }
  fi
  log "Installed and configured nginx successfully"
}
install_portainer() {
  log "Installing portainer...Please wait" INFO
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
  apt-get -y install vsftpd
  # Check if passive or active mode. Currently it's only for passive mode.
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/vsftpd.pem -out /etc/ssl/private/vsftpd.pem

  # Backup old config
  timestamp=$(date +%s)
  cp /etc/vsftpd.conf $cwd/backups/vsftpd/$timestamp/vsftpd.conf

  # Allow ports for vsftpd
  ufw allow 20/tcp,21/tcp,990/tcp,40000:50000/tcp

  # Enable fail2ban jail
  replace "[vsftpd]" "[vsftpd]\nenabled=true" /etc/vsftpd.conf

  log "Installed vsftpd. Make sure to add all users you want to grant access to /etc/vsftpd.userlist" INFO
}
install_certbot() {
  apt install -y certbot python3-certbot-apache
}