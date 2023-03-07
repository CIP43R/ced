log() {
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
  esac
  sleep 0.5
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
confirm() {
  read -r -p "${1} [y/N] " response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      echo true
  else
      echo false
  fi
}
compare() {
  if grep -wq "$1" $2; then 
    echo true
  else 
    echo false
  fi
}
replace() {
  sudo sed -i -e "s/$1/$2/g" "$3"
  #tr $1 $2 < $3 # TODO: needs testing
}
prop() {
  echo $(grep "${1}" $2|cut -d'=' -f2)
}
getconf() {
  echo $(prop ${1} ${cwd}/config.conf)
}
setconf() {
  sed -i "/${1}/c\\${1}=${2}" $cwd/config.conf
}
file_exists() {
  if [ -f $1 ]; then
    echo true
  else echo false
  fi
}
command_exists() {
  if [ -x "$(command -v $1)" ]; then
    echo true
  else echo false
  fi
}
