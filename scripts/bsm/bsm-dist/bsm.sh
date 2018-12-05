#!/bin/sh

# =================================================================
# IMPORTS
# =================================================================
BSM_INSTALL_PATH="$HOME/.bsm"

source "$BSM_INSTALL_PATH/lib/local.sh"
source "$BSM_INSTALL_PATH/lib/vars.sh"
source "$BSM_INSTALL_PATH/lib/functions.sh"

# =================================================================
# PROCESS COMMANDLINE ARGUMENTS
# =================================================================

# Usage: COMMAND -h -v -s <searchprocs> -o <localhosts>

# Priorities: for COMMAND options
# * process the top-level options in the following priority:
#   + -S: launch all BL services
#   + -k: kill-signals for specific services
#   + -o: open a localhost for a specific service
#   + -s: overall status for majority of services
#   + -f: fetch status for specific services

declare -a SERVICES
index=0

while getopts f:k:s:u:FKSUhv option
do
  case "${option}"
  in
    S) cd $BL_PROJECT_PATH && foreman start && exit 0;;
    s) echo "TODO: SERVICES STATUS" && exit 0;;     # NOT YET IMPLEMENTED
    K) SHUTDOWN_APP="all";;
    k) SHUTDOWN_APP=${OPTARG};;
    U) OPEN_URLS="all";;
    u) OPEN_URLS=${OPTARG};;
    F) SEARCH_APPS="all";;
    f) SEARCH_APPS=${OPTARG};;
    h) HELP="TRUE";;
    v) VERBOSE="TRUE";;
    \?) echo "${colRED}\nERROR: Invalid option.${NC}\n" && show_help && exit -1;;
  esac
done


# --------------------
# TODO: Add puma, sidekiq, serviceworker(s) to this control flow
# --------------------
case "$SEARCH_APPS"
  in
  "mongod")
    service_status "$search_mongo" "mongod" && display_running && \
      exit 0;;
  "redis")
    service_status "$search_redis" "redis" && display_running && \
      exit 0;;
  "polyapp")
    service_status "$search_polyapp" "poly-app" && display_running && \
      exit 0;;
  "polyweb")
    service_status "$search_polyweb" "poly-web" && display_running && \
      exit 0;;
  "proxy")
    service_status "$search_proxy" "proxy" && display_running && \
      exit 0;;
  "rails")
    service_status "$search_rails" "rails" && display_running && \
      exit 0;;

  "dbs") #eval $search_dbs && exit 0;;
    service_status "$search_dbs" "all-dbs" && display_running && \
      exit 0;;
  "poly") #eval $search_polyall && exit 0;;
    service_status "$search_polyall" "poly-all" && display_running && \
      exit 0;;
  "all")
    service_status "$search_mongo" "mongod"
    service_status "$search_redis" "redis"
    service_status "$search_rails" "rails"
    service_status "$search_polyapp" "polyapp"
    service_status "$search_polyweb" "polyweb"
    service_status "$search_proxy" "proxy"

    display_running
    exit 0
    ;;
  "*") echo "${colRED}ERROR: Invalid SEARCH option.${NC}" && show_help && exit -1;;
esac


# --------------------
# TODO: Add puma, sidekiq, serviceworker(s) to this control flow (if applicable)
# --------------------
case "$OPEN_URLS"
  in
  "rails")
    $browser_open $host_rails && \
      exit 0
    ;;
  "polyapp")
    $browser_open $host_polyapp && \
      exit 0
    ;;
  "polyweb")
    $browser_open $host_polyweb && \
      exit 0
    ;;
  "proxy")
    $browser_open $host_proxy && \
      exit 0
    ;;
  "all")
    $browser_open $host_proxy && \
      $browser_open $host_rails && \
      $browser_open $host_polyapp && \
      $browser_open $host_polyweb && \
      exit 0
    ;;
  *) echo "${colRED}ERROR: Invalid BROWSER-OPEN option.${NC}";;
esac

# --------------------
# TODO: Add puma, sidekiq, serviceworker(s) to this control flow (if applicable)
# --------------------
case "$SHUTDOWN_APP"
  in
  "rails")
    echo "TODO:FiXME: feature not yet implmented" && \
      exit 0
    ;;
  "polyapp")
    echo "TODO:FiXME: feature not yet implmented" && \
      exit 0
    ;;
  "polyweb")
    echo "TODO:FiXME: feature not yet implmented" && \
      exit 0
    ;;
  "proxy")
    echo "TODO:FiXME: feature not yet implmented" && \
      exit 0
    ;;
  "all")
    echo "TODO:FiXME: feature not yet implmented" && \
      exit 0
    ;;
  *)
    echo "${colRED}ERROR: Invalid BROWSER-OPEN option.${NC}" && \
      exit 0
    ;;
esac


# show HELP options if help option is set
[ ! -z "$HELP" ] && show_help && exit -1

# if the VERBOSE option is set, enable additional output messages
[ ! -z "$VERBOSE" ] && echo "VERBOSE OUTPUT ENABLED: "


