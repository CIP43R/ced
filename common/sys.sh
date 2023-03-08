backup() {
  # Make a netplan backup to prevent network config issues
  mkdir -p $cwd/backups/netplan
  sudo cp /etc/netplan/* $cwd/backups/netplan/
  log "Created a copy of netplan config in $cwd/backups/netplan" INFO
}
update() {
  # Make sure to backup important config files before update
  backup
  
  log "Installing updates...this may take a while" INFO
  { 
    touch $cwd/logs/install.log
    touch $cwd/logs/full.log
    sudo apt update && apt upgrade -y
  } &> $aptlogloc
  log "Updated system packages" INFO
}
jail() {
  if [[ $(command_exists "fail2ban") = false ]]; then
    install_fail2ban
  fi
  replace "[$1]" "[$1]\nenabled=true" /etc/fail2ban/jail.local
}
nginx_ok() {
  out=$(nginx -t 2>&1)
  if $out; then
    echo true
  else
    $out > $cmdlogloc
    echo false
  fi
}
silent_tee() {
  echo $1 | sudo tee -a $2 &> /dev/null 
}