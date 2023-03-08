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

# $1: String to replace
# $2: String that replaces the found string
# $3: File where we should replace the occurance
# Warning: Replaces ALL occurances!
replace() {
  sudo sed -i -e "s/$1/$2/g" "$3"
  #tr $1 $2 < $3 # TODO: needs testing
}
prop() {
  echo $(grep "${1}" $2|cut -d'=' -f2)
}
getconf() {
  echo $(prop ${1} $config_path)
}
setconf() {
  sed -i "/${1}/c\\${1}=${2}" $config_path
}
any_file_exist() {
  files=$(shopt -s nullglob dotglob; echo $1)
  if [ "${#files}" ]; then
    echo true
  else echo false
  fi
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