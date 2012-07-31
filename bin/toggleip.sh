#!/usr/bin/sh
  case $1 in
  'h')
    netsh interface ipv4 set address name="Local Area Connection" source=static address=192.168.1.22 mask=255.255.255.0 gateway=192.168.1.4
    netsh interface ipv4 add dnsserver name="Local Area Connection" address=209.18.47.61 index=2
  ;;
  'o')
    netsh interface ipv4 set address name="Local Area Connection" source=dhcp
    netsh interface ipv4 set dns name="Local Area Connection" source=dhcp
  ;;
  *)
    echo 'usage:toggleid [h|o]' 
  ;;
  esac
