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
  echo "Delete a zone and all of it's records."
  echo ""
  echo "usage: $thisfilename -z <zone> [-x] [-h]"
  echo ""
  echo "  -h            Print this help."
  echo "  -z <zone>     Zone (domain name) to delete."
  echo "  -x            Execute (force) - don't prompt for confirmation."
}

pdns:getoptions "$@"

# check for zone
if [[ -z $zone ]]; then
  echo "zone is required"
  exit
fi

if [[ -n $execute ]] || pdns::yesno "Delete $zone now?"; then
  echo
  zone_status=$(/usr/bin/curl --silent --output /dev/null --write-out "%{http_code}" --request DELETE --header "X-API-Key: $api_key" $api_base_url/zones/$zone)
  if [[ $zone_status = 204 ]]; then
    echo Zone $zone deleted.
  elif [[ $zone_status = 404 ]]; then
    echo Zone $zone does not exist.
  else
    echo Error. http response deleting zone $zone was: $zone_status
  fi
fi
