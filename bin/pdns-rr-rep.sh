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
  echo "Replace Resource Record set in zone."
  echo ""
  echo "usage: $thisfilename -z <zone> -n <name> -t <type> -r <record> [-l <ttl>] [-s <status>] [-c <comment>] [-a <account>] [-h]"
  echo ""
  echo "  -h            Print this help."
  echo "  -z <zone>     Zone (domain name) to modify records."
  echo "  -n <name>     Hostname for this record."
  echo "  -t <type>     Type of record to modify (A, CNAME, TXT, etc.)."
  echo "  -r <record>   Resource record content (data / values)."
  echo "  -l <ttl>      TTL, optional, defaults to $zone_defaults_ttl."
  echo "  -s <0|1>      Status, optional. O (default) for active or 1 for disabled."
  echo "  -c <comment>  An optional comment/note about the record."
  echo "  -a <account>  The account that the comment gets attributed too."
  echo "                Only used if comment is set. Optional, defaults to hostname of server running this script."
  echo
  echo "                If record(s) do not exist they are created, if they already exist they are replaced."
  echo "                Record Sets are matched against zone, name & type. This tool updates/replaces all records"
  echo "                that match the specified name & type. <content> is the data for the record and can be multiple"
  echo "                records with each record separated by a pipe (|). In the case where you have multiple records"
  echo "                that match the specified name & type you must specify *all* of the records. If for example"
  echo "                you want to add a third NS record to a domain that already has a two NS records you must"
  echo "                specify all 3 NS records in the <content>, otherwise the 2 existing records will be deleted"
  echo "                and the single new record will be added from the <content>".
  echo "                When adding MX or SRV records specify the Priority as part of the record. e.g. -c \"10 mail.example.com\""
  echo "                Only MX & SRV records use Priority, leave Priority off all other records."
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

# check for record data
if [[ -z $record ]]; then
  echo "record is required"
  exit
fi

# check for ttl
if [[ -z $ttl ]]; then
  ttl=$zone_defaults_ttl
fi

# first query to see if zone already exists
zone_status=$(/usr/bin/curl --silent --output /dev/null --write-out "%{http_code}" -H "X-API-Key: $api_key" "$api_base_url/zones/$zone?rrsets=false")

if [[ $zone_status = 200 ]]; then
  # verified zone exists, add record(s)

  data="{\"rrsets\":[{\"name\":\"$name\",\"type\":\"$type\",\"ttl\":$ttl,\"changetype\":\"REPLACE\",\"records\":["

  # turn record in to array of records
  orig_ifs="$IFS"
  IFS='|'
  read -r -a resourcerecords <<< "$record"
  IFS="$orig_ifs"

  # get number of records in set
  resourcerecords_records_count=${#resourcerecords[@]}
  records_count=0

  for resourcerecord in "${resourcerecords[@]}"; do

    records_count=$((records_count+1))

    # make sure hostnames end in a .
    declare -a types_that_require_dot=("CNAME MX NS PTR SRV")
    if [[ " ${types_that_require_dot[*]} " =~ " ${type} " ]]; then
      if [[ $resourcerecord != *\. ]]; then
        resourcerecord="$resourcerecord."
      fi
    fi

    # quote TXT records
    if [[ $type = "TXT" ]]; then
      resourcerecord="\\\"$resourcerecord\\\""
    fi

    # set disabled status
    if [[ $status = 1 ]]; then
      disabled=true
    else
      disabled=false
    fi

    data="$data{\"content\":\"$resourcerecord\",\"disabled\":$disabled}"

    if [[ $records_count < $resourcerecords_records_count ]]; then
      data="$data,"
    else
      data="$data]"
    fi

  done

  # add comment, if set
  if [[ -n $comment ]]; then
    # set account to hostname if not specified with -a option
    if [[ -z $account ]]; then
      account=$(/usr/bin/hostname -f)
    fi
    data= "$data,\"comments\":[{\"content\":\"$comment\",\"account\":\"$account\"}]"
  fi

  # close out json string
  data="$data}]}"

  # add record(s)
  zone_status=$(/usr/bin/curl --silent --request PATCH --output /dev/null --write-out "%{http_code}" --header "X-API-Key: $api_key" --data "$data" "$api_base_url/zones/$zone")

  if [[ $zone_status = 204 ]]; then
    echo "Success. Record(s) for $zone created/updated."
  else
    echo "Error. http response updating record(s) for $zone was: $zone_status"
  fi

elif [[ $zone_status = 404 ]]; then

  echo "Zone $zone does not exist, can't update records."

else
  echo "Unexpected http response checking for Zone $zone: $zone_status"
fi
