# =================================================================
# UTILITY-FUNCTIONS
# =================================================================

### TODO: add these to the HELP menu in future ??
# * serviceworker    : PORT:????
# * sidekiq          : PROCESS:'sidekiq'
# * puma             : PROCESS:'puma'
# * .. other??
show_help() {
  echo "${colYLW}Usage: bsm <option> [arg] ${NC}"
  echo "    ${colCYN}This script facilitates the management of BL services ${NC}"
  echo "    ${colCYN}during development.  Specifically, it helps a developer ${NC}"
  echo "    ${colCYN}to manage the following: ${NC}"
  echo "    ${colCYN}  * Starting and stopping services ${NC}"
  echo "    ${colCYN}  * Searching for running services ${NC}"
  echo "    ${colCYN}  * Quickly launching browser client for running services ${NC}"
  echo ""
  echo ""
  echo "${colYLW}Basic Options:${NC}"
  echo "    ${colLBL}-S         ${NC}\t Launch all servers from a clean start"
  echo "    ${colRED}-s <APP>   \t TODO:FIXME: start a specific stopped service${NC}"
  echo "    ${colRED}-K         \t TODO:FIXME: shortcut for '-k all' -- Stop all running BL services${NC}"
  echo "    ${colLBL}-k <APP>   ${NC}\t stop a specific, currently-running BL service"
  echo "    ${colRED}-U         \t TODO:FIXME: shortcut for '-u all' -- launch local client for all BL services${NC}"
  echo "    ${colLBL}-u <APP>   ${NC}\t launch the local client for a specific service"
  echo "    ${colLBL}-F         ${NC}\t shortcut for '-f all' -- search for any running BL apps"
  echo "    ${colLBL}-f <APP>   ${NC}\t check if a specific BL app is currently running"
  echo ""
  echo ""
  echo "${colYLW}Misc Options:${NC}"
  echo "    ${colLBL}-h         ${NC}\t Show HELP options"
  echo "    ${colLBL}-v         ${NC}\t Verbose output"
  echo ""
  echo ""
  echo "${colYLW}APP Options:${NC}"
  echo "    ${colLBL}4000|proxy       ${NC}the proxy service"
  echo "    ${colLBL}5000|rails       ${NC}the rails service"
  echo "    ${colLBL}8500|polyapp     ${NC}the polymer app"
  echo "    ${colLBL}8510|polyweb     ${NC}the polymer website"
  echo "    ${colLBL}6379|redis       ${NC}the redis service"
  echo "    ${colLBL}27017|mongod     ${NC}the mongo db service"
  echo ""
  echo "    ${colLGY}puma             ${NC}TODO: this option not yet implemented"
  echo "    ${colLGY}sidekiq          ${NC}TODO: this option not yet implemented"
  echo "    ${colLGY}serviceworker    ${NC}TODO: this option not yet implemented"
  echo ""
  echo ""
  echo "${colYLW}Examples:${NC}"
  echo "    ${colLBL}bsm -k 4000      ${NC}# shut down the proxy service"
  echo "    ${colLBL}bsm -s 5000      ${NC}# launch the rails service"
  echo "    ${colLBL}bsm -f redis     ${NC}# check if the redis service is currently running"
  echo "    ${colLBL}bsm -u polyapp   ${NC}# launch the web page for the polymer-app"
  echo ""
  echo ""
}


# ------------------------------
# TBD
# ------------------------------
service_status() {
  service_search=$1
  service_name=$2

  declare -a SVC
  idx=0


  # Use a 'here-string' to send multi-line input into the 'while:do:done' loop
  #   - REASON: piping into a while-loop creates a subshell, so any variables will
  #     disappear after the subshell exits
  #
  while read line; do SVC[$idx]="$line" && ((idx++)); done <<< "$(eval $service_search)"

  for zats in "${SVC[@]}"; do
    service="$(echo $zats | awk -F" " -v name=$service_name 'BEGIN { OFS=":" } { print name, $2 }')"
    SERVICES[$index]=$service

    let "index = $index + 1"
    # --- echo $service
  done
}


# ------------------------------
# Function is used to pretty-print the APPNAME:PORTNUMBER pair of values
#   that are the output of any search for running services
#
#   - running-services strings are expected to be stored (one APP:PORT
#     pair per record) in the array called 'SERVICES'
#   - per-record expected input format ==> APPNAME:PORT
#
# ------------------------------
display_running() {
  # Add color output for awk, see this SO reference:
  #   - https://stackoverflow.com/a/46043780/4561730
  YELLOW='\033[01;33m'
  LBLU='\033[01;34m'
  LCYN='\033[01;36m'
  LGRY='\033[00;37m'

  # --- HEADINGS for the pretty-printed ascii table
  echo ""
  echo "${colCYN}  RUNNING SERVICES:${NC}"
  echo "${colLBY}  -----------------${NC}"
  printf "%2s%-10s | %-7s\n" " " "APPNAME" "PORT"
  echo "${colLBY}  -----------------${NC}"

  # --- iterate through the SERVICES array to print out
  #   each record-pair (one line per record)
  for upservice in "${SERVICES[@]}"; do
    echo "$upservice" | awk -F: -v y=$YELLOW -v b=$LBLU -v g=$LGRY -v n=$NC \
      '{ printf "%2s %-10s %3s %-7s\n", " ", b$1n, " | ", y$2n }'
  done

  echo ""
  echo ""
}

