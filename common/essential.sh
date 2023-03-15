#!/bin/bash

log() {
  config_log_level=$(get_conf "log_level")
  log_level=${config_log_level:-2}
  
  case $2 in
    DEBUG)
      if [[ $(get_conf "log_level") -lt 1 ]]; then
        printf "${BLUE}[DEBUG] $1\\n" | tee -a $logloc
      fi
      ;;
    VERBOSE)
      if [[ $(get_conf "log_level") -lt 2 ]]; then
        printf "${BLUE}[VERBOSE] $1\\n" | tee -a $logloc
      fi
      ;;
    INFO)
      if [[ $(get_conf "log_level") -lt 3 ]]; then
        printf "${BLUE}[INFO] $1\\n" | tee -a $logloc
      fi
      ;;
    WARN)
      if [[ $(get_conf "log_level") -lt 3 ]]; then
      printf "${YELLOW}[WARN] $1\\n" | tee -a $logloc
      fi
      ;;
    ERROR)
      printf "${RED}[ERROR] $1\\n" | tee -a $logloc
      exit 32
      ;;
    *)
      printf "Wrong call! $2"
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

get_conf() {
  echo $(get_prop $1 $config_path)
}
set_conf() {
  set_prop $1 $2 $config_path
}
command_exists() {
  if [ -x "$(command -v $1)" ]; then
    echo true
  else echo false
  fi
}