#!/bin/bash

chmod 755 bin/*
cp bin/* /usr/local/bin/

if [[ ! -f /usr/local/etc/pdns.conf ]]; then
  chmod 640 etc/pdns.conf
  cp etc/pdns.conf /usr/local/etc/pdns.conf
  echo "Install complete, but sure to update /usr/local/etc/pdns.conf with your settings."
fi
