#!/bin/sh

# colors for better message visibility on the commandline
# REFERENCE: https://stackoverflow.com/questions/5947742/how-to-change-the-output-color-of-echo-in-linux
colRED='\033[0;31m'     # normal red
colLBL='\033[1;34m'     # light blue
colCYN='\033[0;36m'     # normal cyan
NC='\033[0m'            # No Color

# ---
# Get the current working path for this 'setup' script.  It will be assumed some other
# files will exist relative to this path. The source for this snippet to obtaining the
# CWD for this setup script can be found here:
#   SOURCE: https://stackoverflow.com/questions/1519006/how-do-you-create-a-remote-git-branch
#
CWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

ENVFILE="$CWD/bsm-dist/lib/local.sh"

if [ -f $ENVFILE ]; then
  echo ""
  echo "${colRED}File $ENVFILE exists.${NC}"
  echo ""

  # TASK: import local environment setup preferences from '.env' file
  source $ENVFILE

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
  echo "${colLBL}  * rename the ${colCYN}$CWD/bsm-dist/lib/LOCAL${colLBL} file as:"
  echo "${colLBL}     + ${colCYN} $ENVFILE ${colLBL}"
  echo "${colLBL}  * edit any variables in the ${colCYN}.env${colLBL} file to reflect the environment${NC}"
  echo "${colLBL}     on your local development machine.${NC}"

  echo ""
  echo ""
fi

