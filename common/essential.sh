#!/bin/bash

log() {
  config_log_level=$(getconf "log_level")
  log_level=${config_log_level:-2}
  
  case $2 in
    DEBUG)
      if [[ $(getconf "log_level") -lt 1 ]]; then
        printf "${BLUE}[DEBUG] $1\\n" | tee -a $logloc
      fi
      ;;
    VERBOSE)
      if [[ $(getconf "log_level") -lt 2 ]]; then
        printf "${BLUE}[VERBOSE] $1\\n" | tee -a $logloc
      fi
      ;;
    INFO)
      if [[ $(getconf "log_level") -lt 3 ]]; then
        printf "${BLUE}[INFO] $1\\n" | tee -a $logloc
      fi
      ;;
    WARN)
      if [[ $(getconf "log_level") -lt 3 ]]; then
      printf "${YELLOW}[WARN] $1\\n" | tee -a $logloc
      fi
      ;;
    ERROR)
      printf "${RED}[ERROR] $1\\n" | tee -a $logloc
      exit 32
      ;;
    *)
      printf "Wrong call!"
      ;;
  esac
}

print_help() {
  echo "
    $cli_use_name
    CED CLI
    Version: $(cat $cwd/VERSION)
    Usage: $cli_use_name $1 <options>
    Options: 
      $2
  "
}

getconf() {
  echo $(get_prop $1 $config_path)
}
setconf() {
  set_prop $1 $2 $config_path
}
command_exists() {
  if [ -x "$(command -v $1)" ]; then
    echo true
  else echo false
  fi
}