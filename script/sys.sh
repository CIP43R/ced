backup() {
  # Make a netplan backup to prevent network config issues
  mkdir -p $cwd/backups/netplan
  cp /etc/netplan/* $cwd/backups/netplan/
  log "Created a copy of netplan config in $cwd/backups/netplan" INFO
}