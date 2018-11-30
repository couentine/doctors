# =================================================================
# MISC-DEFAULTS
# =================================================================

### search for running services
# -- rails services
# -- search_rails="ps aux | grep -E 'sidekiq|puma'"
search_rails="lsof | grep LISTEN | grep -E '5000|:commplex-main'"

# -- storage servers
search_dbs="lsof | grep LISTEN | grep -E 'localhost:6379|localhost:27017|redis|mongod'"
search_mongo="lsof | grep LISTEN | grep -E 'localhost:27017|mongod'"
search_redis="lsof | grep LISTEN | grep -E 'localhost:6379|redis'"

# -- polymer apps
search_polyall="lsof | grep LISTEN | grep -E '8500|8510|localhost:fmtp'"
search_polyapp="lsof | grep LISTEN | grep -E '8500|localhost:fmtp'"
search_polyweb="lsof | grep LISTEN | grep -E '8510'"

# -- reverse proxy
search_proxy="lsof | grep LISTEN | grep -E '4000|:terabase'"

# TODO: -- serviceworker
# TODO: ----- search_sw=""


# ABBREVIATED search-options
OPTRAILS='r'
OPTDBS='d'
OPTPOLY='p'
OPTPROXY='x'


# BL localhost urls
host_proxy="http://localhost:4000"
host_rails="http://localhost:5000"
host_polyapp="http://localhost:8500"
host_polyweb="http://localhost:8510"


# utility variables
HELP=""
VERBOSE=""
MSG_SEPARATOR="${colLGY}\t....................${NC}\n"


# =================================================================
# COLOR-DEFINITIONS
# =================================================================

# colors for better message visibility on the commandline
# REFERENCE: https://stackoverflow.com/questions/5947742/how-to-change-the-output-color-of-echo-in-linux
colRED='\033[0;31m'     # normal red
colGRN='\033[0;32m'     # normal green
colYLW='\033[1;33m'     # normal yellow
colBLU='\033[0;34m'     # normal blue
colPRP='\033[0;35m'     # normal purple
colCYN='\033[0;36m'     # normal cyan
colLGY='\033[0;37m'     # light grey

colDGY='\033[1;30m'     # dark grey
colLRD='\033[1;31m'     # light red
colLGR='\033[1;32m'     # light green
colLBL='\033[1;34m'     # light blue
colLPP='\033[1;35m'     # light purple
colLCY='\033[1;36m'     # light cyan
NC='\033[0m'            # No Color


