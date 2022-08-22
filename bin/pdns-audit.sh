#!/bin/bash
#
# powerdns-tools
# https://git.stack-source.com/msb/powerdns-tools
# Copyright (c) 2022 Matthew Saunders Brown <matthewsaundersbrown@gmail.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)
#
# Basic PowerDNS audit tool. Gets list of zones from pdns database
# and does DNS lookups on their nameservers to see if the zone uses
# your nameservers or not (as listed in the authoritative() array below).
# This tool does not check for mismatched NS records, for example what
# is listed with the domain registrar is not what's configured in DNS.
# This tool should be run as root or another user that has access to
# the pdns database without having to specify connection info. For
# example a fully configured .my.cnf user file can provide this.
# For domains that are found to be using other nameservers than yours
# the A & MX records are listed, the idea being you can check against
# that to determine if the domains are using your hosting services.
# No action is taken, this just provides a report that can be reviewed.

# set array of our nameservers
authoritative=(ns1.example.com. ns2.example.com. ns3.example.com.)

# create array of domains from pdns database:
domains=(`mysql -s -e "SELECT LOWER(name) FROM pdns.domains"`)

# cycle through each domain
for domain in "${domains[@]}"; do
  # get nameservers for domain
  nameservers=(`/usr/bin/dig $domain ns +short`)
  # check number of nameservers returned
  if [[ ${#nameservers[@]} = 0 ]]; then
    # domain returns zero nameservers (either unregistered, or registered but no NS entries configured in DNS)
    echo ZERO: $domain
  elif [[ ${#nameservers[@]} -gt 0 ]]; then
    usesours=FALSE
    for nameserver in "${nameservers[@]}"; do
      if [[ " ${authoritative[*]} " =~ " ${nameserver} " ]]; then
        usesours=TRUE
      fi
    done
    if [[ $usesours = FALSE ]]; then
      # domain uses other nameservers than ours
      unset arecord
      unset mxrecord
      arecord=`/usr/bin/dig $domain +short`
      mxrecord=`/usr/bin/dig $domain mx +short`
      echo OTHER: $domain - $arecord - $mxrecord
    else
      # domain uses our nameservers
      echo VERIFIED: $domain
    fi
  else
    # error getting nameservers
    echo ERROR: $domain
  fi
done
