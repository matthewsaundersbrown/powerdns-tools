#!/bin/bash
#
# powerdns-tools
# https://git.stack-source.com/msb/powerdns-tools
# Copyright (c) 2022 Matthew Saunders Brown <matthewsaundersbrown@gmail.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DEBIAN_FRONTEND=noninteractive apt-get -y install pip
pip install certbot-dns-powerdns

if [[ ! -f /root/.pdns-credentials.ini ]]; then
  echo "certbot_dns_powerdns:dns_powerdns_api_url =" > /root/.pdns-credentials.ini
  echo "certbot_dns_powerdns:dns_powerdns_api_key =" >> /root/.pdns-credentials.ini
  chmod 640 /root/.pdns-credentials.ini
  echo "Update /root/.pdns-credentials.ini with your settings (this is to be used with certbot-dns-powerdns)."
fi

chmod 755 bin/*
cp bin/* /usr/local/bin/

if [[ ! -f /usr/local/etc/pdns.conf ]]; then
  cp etc/pdns.conf /usr/local/etc/pdns.conf
  chmod 640 /usr/local/etc/pdns.conf
  echo "Update /usr/local/etc/pdns.conf with your settings."
fi
