log() {
  case $2 in
    INFO)
      printf "${BLUE}[INFO] $1\\n" | tee -a $logloc
      ;;
    WARN)
      printf "${YELLOW}[WARN] $1\\n" | tee -a $logloc
      ;;
    ERROR)
      printf "${RED}[ERROR] $1\\n" | tee -a $logloc
      exit
      ;;
  esac
  sleep 0.5
}
confirm() {
  read -r -p "${1} [y/N] " response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      confirmed=true
  else
      confirmed=false
  fi
}
compare() {
  if grep -wq "$1" $2; then 
    compared=true
  else 
    compared=false
  fi
}
replace() {
  sed -i -e "s/$1/$2/g" "$3"
  #tr $1 $2 < $3 # TODO: needs testing
}