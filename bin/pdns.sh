#!/bin/bash
#
# powerdns-tools
# https://git.stack-source.com/msb/powerdns-tools
# Copyright (c) 2022 Matthew Saunders Brown <matthewsaundersbrown@gmail.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)
#
# powerdns-tools include file, used by other powerdns-tools bash scripts

# Must be root, attempt sudo if need be. root is not actually required for the API commands, but we want to restrict access.
if [ "${EUID}" -ne 0 ]; then
  exec sudo -u root --shell /bin/bash $0 $@
fi

# Load local config
# Two variables, api_key & dns_domain, are only set in the local config
# Any of the other constants below can be overriden in the local config
if [[ -f /usr/local/etc/pdns.conf ]]; then
  source /usr/local/etc/pdns.conf
fi

# constants

# API URL. Consider putting this behind a proxy with https on the front and then setting api_base_url in pdns.conf
[[ -z $api_base_url ]] && api_base_url=http://127.0.0.1:8081/api/v1/servers/localhost

# Default IP address to use for new zone records
# Defaults to IP of server script is run from
[[ -z $default_ip ]] && default_ip=$(hostname --ip-address)

# Array of allowed Resource Record Types
[[ -z $rr_types ]] && declare -a rr_types=(A AAAA CNAME MX NS PTR SRV TXT)

# Minimum/maximum values for SOA and RR records
[[ -z $min_ttl ]] && min_ttl=300
[[ -z $max_ttl ]] && max_ttl=2419200
[[ -z $min_refresh ]] && min_refresh=300
[[ -z $min_retry ]] && min_retry=300
[[ -z $min_expire ]] && min_expire=86400

# Default values for new zones.
[[ -z $zone_default_ns ]] && zone_default_ns="ns1.$dns_domain"
[[ -z $zone_defaults_mbox ]] && zone_defaults_mbox="hostmaster.$dns_domain"
[[ -z $zone_defaults_ttl ]] && zone_defaults_ttl='3600'
[[ -z $zone_defaults_refresh ]] && zone_defaults_refresh='86400'
[[ -z $zone_defaults_retry ]] && zone_defaults_retry='7200'
[[ -z $zone_defaults_expire ]] && zone_defaults_expire='1209600'
[[ -z $zone_defaults_minimum ]] && zone_defaults_minimum='3600'
readonly zone_defaults_pri='0'
# zone_defaults_pri must be 0, do not change

# The following array specifies default records for new zone records.
# These get inserted automatically whenever a zone is created.
# The format of each record is (name|type|content). TTL is taken from defaults above.
# @ will be replace with the zone (domain name)
# TXT records will get quoted (don't add quotes around the content field here)
# Only MX & SRV records use priority, and it should be specified as part of the content/data field.

[[ -z $default_records ]] && declare -a default_records=("@|A|$default_ip"
                                                         "@|MX|10 mail.@"
                                                         "@|NS|ns1.$dns_domain"
                                                         "@|NS|ns2.$dns_domain"
                                                         "@|NS|ns3.$dns_domain"
                                                         "@|TXT|v=spf1 a mx -all"
                                                         "mail.@|A|$default_ip"
                                                         "www.@|CNAME|@")

# functions

# crude but good enough domain name format validation
function vmail::validate_domain () {
  local my_domain=$1
  if [[ $my_domain =~ ^(([a-zA-Z0-9](-?[a-zA-Z0-9])*)\.)+[a-zA-Z]{2,}\.?$ ]] ; then
    return 0
  else
    return 1
  fi
}

# yesno prompt
#
# Examples:
# loop until y or n:  if vmail::yesno "Continue?"; then
# default y:          if vmail::yesno "Continue?" Y; then
# default n:          if vmail::yesno "Continue?" N; then
function pdns::yesno() {

  local prompt default reply

  if [ "${2:-}" = "Y" ]; then
    prompt="Y/n"
    default=Y
  elif [ "${2:-}" = "N" ]; then
    prompt="y/N"
    default=N
  else
    prompt="y/n"
    default=
  fi

  while true; do

    read -p "$1 [$prompt] " -n 1 -r reply

    # Default?
    if [ -z "$reply" ]; then
      reply=$default
    fi

    # Check if the reply is valid
    case "$reply" in
      Y*|y*) return 0 ;;
      N*|n*) return 1 ;;
    esac

  done

}

function pdns:getoptions () {
  local OPTIND
  while getopts "hbz:m:t:a:n:r:c:l:s:x" opt ; do
    case "${opt}" in
        h ) # display help and exit
          help
          exit
          ;;
        b ) # bare - create empty zone, do not any default records
          bare=true
          ;;
        z ) # zone
          zone=${OPTARG,,}
          # pdns stores zone name without trailing dot, remove if found
          if [[ ${zone: -1} = '.' ]]; then
            zone=${zone::-1}
          fi
          if ! vmail::validate_domain $zone; then
            echo "ERROR: $zone is not a valid domain name."
            exit
          fi
          ;;
        m ) # master - IP of master if this is a slave zone
          master=${OPTARG}
          ;;
        t ) # type
          type=${OPTARG^^}
          ;;
        a ) # account
          account=${OPTARG}
          ;;
        n ) # name - hostname for this record
          name=${OPTARG,,}
          ;;
        r ) # record data
          record=${OPTARG}
          ;;
        c ) # comment - a note about the record
          comment=${OPTARG}
          ;;
        l ) # ttl - Time To Live
          ttl=${OPTARG}
          ;;
        s ) # status - disabled status, 0 for active 1 for inactive, default 0
          status=${OPTARG}
          ;;
        x ) # eXecute - don't prompt for confirmation
          execute=true
          ;;
        \? )
          echo "Invalid option: $OPTARG"
          exit 1
          ;;
        : )
          echo "Invalid option: $OPTARG requires an argument"
          exit 1
        ;;
    esac
  done
  shift $((OPTIND-1))
}
