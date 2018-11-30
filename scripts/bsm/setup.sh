#!/bin/sh

# colors for better message visibility on the commandline
# REFERENCE: https://stackoverflow.com/questions/5947742/how-to-change-the-output-color-of-echo-in-linux
colRED='\033[0;31m'     # normal red
colLBL='\033[1;34m'     # light blue
colCYN='\033[0;36m'     # normal cyan
NC='\033[0m'            # No Color

ENVFILE="./.env"

if [ -f $ENVFILE ]; then
  echo ""
  echo "${colRED}File $ENVFILE exists.${NC}"
  echo ""

  # TASK: import local environment setup preferences from '.env' file
  source .env

  # TASK: create the top-level ~/.bsm folder
  mkdir ~/.bsm

  # TASK: copy all *.sh files into ~/.bsm
  cp -R ./bsm-dist/ ~/.bsm/

  # TASK: add executable permissions to the 'bsm' script
  chmod u+x ~/.bsm/bsm.sh

  # TASK: add alias to BSM script
  $(echo "alias bsm='~/.bsm/bsm.sh'" >> "$bsm_alias_file")
else
  echo ""
  echo "${colRED}ERROR: File $ENVFILE does NOT exist.${NC}"
  echo ""
  echo "${colLBL}To fix this: ${NC}"
  echo "${colLBL}  * rename the ${colCYN}ENV${colLBL} file as ${colCYN}.env${colLBL} in the same folder as this setup.sh file${NC}"
  echo "${colLBL}  * edit any variables in the ${colCYN}.env${colLBL} file to reflect the environment${NC}"
  echo "${colLBL}      on your local development machine.${NC}"

  echo ""
  echo ""
fi

