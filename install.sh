#!/bin/bash

apt install pip
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
