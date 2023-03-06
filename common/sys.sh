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
  replace "[$1]" "[$1]\nenabled=true" /etc/fail2ban/jail.local
}