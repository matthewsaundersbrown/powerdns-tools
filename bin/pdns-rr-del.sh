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
  echo "Delete Resource Record set in zone."
  echo ""
  echo "usage: $thisfilename -z <zone> -n <name> -t <type> [-h]"
  echo ""
  echo "  -h            Print this help."
  echo "  -z <zone>     Zone (domain name) to modify."
  echo "  -n <name>     Hostname for the record(s) to delete."
  echo "  -t <type>     Type of record(s) to del (A, CNAME, TXT, etc.)."
  echo
  echo "                Record Sets are matched against zone, name & type. This tool deletes all records"
  echo "                that match the specified name & type for the given zone."
  echo "                <name> Can be a FQDN, or just the subdomain part (zone will be appended) or @ which will be replaced by the zone."
}

pdns:getoptions "$@"

# check for zone, make sure it ends with a .
if [[ -z $zone ]]; then
  echo "zone is required"
  exit
elif [[ $zone != *\. ]]; then
  zone="$zone."
fi

# check for name, make sure it ends with a .
if [[ -z $name ]]; then
  echo "name is required"
  exit
elif [[ $name = "@" ]]; then
  name=$zone
elif [[ $name != *\. ]]; then
  name="$name."
fi

# make sure name is equal to or part of zone
if [[ $name != $zone ]] && [[ $name != *\.$zone ]]; then
  name="$name$zone"
fi

# check for type
if [[ -z $type ]]; then
  echo "type is required"
  exit
fi

# first query to see if zone already exists
zone_status=$(/usr/bin/curl --silent --output /tmp/$zone --write-out "%{http_code}" -H "X-API-Key: $api_key" "$api_base_url/zones/$zone")

if [[ $zone_status = 200 ]]; then
  # verified zone exists, delete record

  data="{\"rrsets\":[{\"name\":\"$name\",\"type\":\"$type\",\"changetype\":\"DELETE\",\"records\":[]}]}"

  # delete record(s)
  zone_status=$(/usr/bin/curl --silent --request PATCH --output "/tmp/$zone" --write-out "%{http_code}" --header "X-API-Key: $api_key" --data "$data" "$api_base_url/zones/$zone")

  if [[ $zone_status = 204 ]]; then
    echo "Success. Record(s) for $zone deleted."
  else
    echo "Error. http response deleting record(s) for $zone was: $zone_status"
  fi

elif [[ $zone_status = 404 ]]; then
  echo "Zone $zone does not exist, can't delete record."
else
  echo "Unexpected http response checking for Zone $zone: $zone_status"
fi

rm /tmp/$zone
