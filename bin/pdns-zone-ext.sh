#!/bin/bash
#
# pdns-tools
# https://git.stack-source.com/msb/pdns-tools
# Copyright (c) 2022 Matthew Saunders Brown <matthewsaundersbrown@gmail.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

# load include file
source $(dirname $0)/pdns.sh

help()
{
  thisfilename=$(basename -- "$0")
  echo "$thisfilename"
  echo "Check if Zone is extant (exits)."
  echo ""
  echo "usage: $thisfilename -z <zone> [-h]"
  echo ""
  echo "  -h            Print this help."
  echo "  -z <zone>     Zone to get."
  echo
  echo "                Echoes 'true' if zone exists, 'false' if zone does not exist, 'error' with exit code 1 on error."
}

pdns:getoptions "$@"

# check for zone
if [[ -z $zone ]]; then
  echo "zone is required"
  exit 1
fi

# export zone and check http status
zone_status=$(/usr/bin/curl --silent --output /dev/null --write-out "%{http_code}" -H "X-API-Key: $api_key" $api_base_url/zones/$zone?rrsets=false)

if [[ $zone_status = 200 ]]; then
  # zone exists
  echo true
elif [[ $zone_status = 404 ]]; then
  # zone does not exist
  echo false
else
  # error, unexpected response code
  echo error
  exit 1
fi
