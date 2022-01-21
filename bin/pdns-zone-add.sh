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
  echo "Add new zone to DNS"
  echo ""
  echo "usage: $thisfilename -z <zone> [-m <master>] [-t <type>]  [-a <account>] [-b] [-h]"
  echo ""
  echo "  -h            Print this help."
  echo "  -z <zone>     Zone (domain name) to add."
  echo "  -m <master>   IP address of master, if this zone is of type SLAVE."
  echo "  -t <type>     Defaults to NATIVE. Can also be MASTER or SLAVE. If type is SLAVE be sure to set master IP."
  echo "  -a <account>  The account that controls this zones. For tying in to Control Panel or other custom admins."
  echo "  -b            Bare - create zone without any Resource Records. Normally a default set of RR are created."
}

pdns:getoptions "$@"

# check for zone
if [[ -z $zone ]]; then
  echo "zone is required"
  exit
fi

# first query to see if zone already exists
zone_status=$(/usr/bin/curl --silent --output /tmp/$zone.output --write-out "%{http_code}" -H "X-API-Key: $api_key" "$api_base_url/zones/$zone")

if [[ $zone_status = 200 ]]; then
  echo Zone $zone already exists.
elif [[ $zone_status = 404 ]]; then

  # zone does not exist, create new zone now

  # generate serial
  serial=$(date +%Y%m%d00)

  # set type (kind). NATIVE (default), MASTER or SLAVE
  if [[ -n $type ]]; then
    kind=$type
  else
    kind="NATIVE"
  fi

  # zone
  data='{'

  if [[ -n $account ]]; then
    data="$data\"account\":\"$account\","
  fi
  data="$data\"name\":\"$zone.\","
  data="$data\"kind\":\"$kind\","
  if [[ -n $master ]]; then
    data="$data\"masters\":[\"$master\"],"
  fi
  data="$data\"serial\":\"$serial\","
  data="$data\"nameservers\":[],"
  data="$data\"rrsets\":["

  # create SOA
  data="$data{"
  data="$data\"name\":\"${zone}.\","
  data="$data\"type\":\"SOA\","
  data="$data\"ttl\":${zone_defaults_ttl},"
  data="$data\"records\":["
  data="$data{"
  data="$data\"content\":\"$zone_default_ns. $zone_defaults_mbox. $serial $zone_defaults_refresh $zone_defaults_retry $zone_defaults_expire $zone_defaults_minimum\"",
  data="$data\"disabled\":false"
  data="$data}"
  data="$data]"


  if [[ -n $bare ]]; then
    # do not add default records
    data="$data}"
  else
    # add default records
    data="$data},"

    # get number of default records to add
    default_records_count=${#default_records[@]}
    records_count=0

    # add default records
    for record in "${default_records[@]}"; do

      records_count=$((records_count+1))

      # replace @ with zone
      record=$(echo ${record} | sed -e "s/@/$zone/g")

      # turn record row info in to array
      orig_ifs="$IFS"
      IFS='|'
      read -r -a recordArray <<< "$record"
      IFS="$orig_ifs"

      # extract record info from array
      rr_name=${recordArray[0]}
      rr_type=${recordArray[1]}
      rr_content=${recordArray[2]}

      # munge data as needed
      if vmail::validate_domain $rr_content; then
        rr_content="$rr_content."
      fi
      if [[ $rr_type = TXT ]]; then
        rr_content="\\\"$rr_content\\\""
      fi
      if [[ $rr_type = MX ]]; then
        rr_content="$rr_content."
      fi

      # add record
      data="$data{"
      data="$data\"name\":\"${rr_name}.\","
      data="$data\"type\":\"${rr_type}\","
      data="$data\"ttl\":${zone_defaults_ttl},"
      data="$data\"records\":["
      data="$data{"
      data="$data\"content\":\"${rr_content}\"",
      data="$data\"disabled\":false"
      data="$data}"
      data="$data]"

      if [[ $records_count = $default_records_count ]]; then
        data="$data}"
      else
        data="$data},"
      fi

    done

  fi

  # close out data
  data="$data]}"

  # add zone
  zone_status=$(/usr/bin/curl --silent --request POST --output "/tmp/$zone.output" --write-out "%{http_code}" --header "X-API-Key: $api_key" --data "$data" "$api_base_url/zones")

  if [[ $zone_status = 201 ]]; then
    echo Success. Zone $zone created.
  else
    echo Error. http response adding zone $zone was: $zone_status
  fi

else
  echo Unexpected http response checking for Zone $zone: $zone_status
fi

rm /tmp/$zone.output
