#!/bin/bash
#
# pdns-tools
# https://git.stack-source.com/msb/pdns-tools
# MIT License Copyright (c) 2022 Matthew Saunders Brown

# load include file
source $(dirname $0)/pdns.sh

help()
{
  thisfilename=$(basename -- "$0")
  echo "$thisfilename"
  echo "Export full DNS zone"
  echo ""
  echo "usage: $thisfilename -z <zone> [-h]"
  echo ""
  echo "  -h            Print this help."
  echo "  -z <zone>     Zone to export."
}

pdns:getoptions "$@"

# check for zone
if [[ -z $zone ]]; then
  echo "zone is required"
  exit
fi

tmpfile=$(mktemp)

# export zone and check http status
zone_status=$(/usr/bin/curl --silent --output "$tmpfile" --write-out "%{http_code}" -H "X-API-Key: $api_key" $api_base_url/zones/$zone/export)

if [[ $zone_status = 200 ]]; then
  # return zone level records
  sed -e 's/\t/|/g' $tmpfile|column -t -s \| |grep ^$zone.
  # return subdomain records
  sed -e 's/\t/|/g' $tmpfile|column -t -s \| |grep -v ^$zone.
elif [[ $zone_status = 404 ]]; then
  echo 404 Not Found, $zone does not exist
else
  echo Unexecpted http response checking for existence of zone $zone: $zone_status
fi

rm $tmpfile
