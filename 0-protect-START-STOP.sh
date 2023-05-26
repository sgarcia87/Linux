#!/bin/sh
# AQQL3
# Script firewall.sh
#

echo "¿Quieres activar (a) o desactivar (d) IPTABLES? (a/d) ENTER PARA SEGUIR"
read resp
echo ""

if [ "$resp" = "a" ]; then

#echo "Iniciando IPTABLES"
# Elimina reglas
iptables -F
iptables -X
iptables -Z

# Politica por defecto: drop
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

# Loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Paquetes invalidos
iptables -A INPUT  -m state --state INVALID -j DROP
iptables -A OUTPUT -m state --state INVALID -j DROP
iptables -A FORWARD -m state --state INVALID -j DROP

# Established & related
#iptables -A OUTPUT -m state --state NEW,ESTABLISHED,RELATED,INVALID -j ACCEPT
#iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

# Salida
iptables -A OUTPUT -p tcp -m tcp --dport 22 -m comment --comment "SSH" -j ACCEPT
iptables -A OUTPUT -p tcp -m tcp --dport 2222 -m comment --comment "SSH" -j ACCEPT
iptables -A OUTPUT -p tcp -m tcp --dport 53 -m comment --comment "DNS-TCP" -j ACCEPT
iptables -A OUTPUT -p udp -m udp --dport 53 -m comment --comment "DNS-UDP" -j ACCEPT
iptables -A OUTPUT -p udp -m udp --dport 67:68 -m comment --comment "DHCP" -j ACCEPT
iptables -A OUTPUT -p tcp -m tcp --dport 80 -m comment --comment "HTTP" -j ACCEPT
iptables -A OUTPUT -p tcp -m tcp --dport 443 -m comment --comment "HTTPS" -j ACCEPT

# allow icmp packets (e.g. ping...)
iptables -A INPUT -p icmp -m state --state NEW -j ACCEPT
iptables -A OUTPUT -p icmp -m state --state NEW -j ACCEPT
echo "IPTABLES ACTIVADO -- OK"
echo ""
elif [ "$resp" = "d" ]; then

#echo "Desactivando IPTABLES"
iptables -F
iptables -X
iptables -Z
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT
echo "IPTABLES DESACTIVADO -- OK"
echo ""
elif [ "$resp" = "" ]; then
echo "SIN CAMBIOS -- OK"
echo ""
elif [ "$resp" != "a" ] || [ "$resp" != "d" ]; then
echo "Opción incorrecta..."
echo ""
fi

#####################################################

echo "¿Quieres activar (a) o desactivar (d) PORTSENTRY? (a/d) ENTER PARA SEGUIR"
read resp
echo ""

if [ "$resp" = "a" ]; then
service portsentry start
echo "PORTSENTRY ACTIVADO -- OK"
echo ""
elif [ "$resp" = "d" ]; then
service portsentry stop
echo "PORTENTRY DESACTIVADO -- OK"
echo ""
elif [ "$resp" = "" ]; then
echo "SIN CAMBIOS -- OK"
echo ""
elif [ "$resp" != "a" ] || [ "$resp" != "d" ]; then
echo "Opción incorrecta..."
echo ""
fi

#####################################################

echo "¿Quieres activar (a) o desactivar (d) el resto de protecciones? (a/d) ENTER PARA SEGUIR"
read resp
echo ""
if [ "$resp" = "a" ]; then
# Quita pings
/bin/echo "1" > /proc/sys/net/ipv4/icmp_echo_ignore_all
echo "PINGS ELIMINADOS -- OK"
# No responder a los broadcast.
/bin/echo "1" > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts
echo "NO RESPONDER BROADCAST -- OK"
# Para evitar el spoofing la dirección  origen del paquete debe venir del sitio correcto.
for interface in /proc/sys/net/ipv4/conf/*/rp_filter; do
/bin/echo "1" > ${interface}
done
echo "VERIFICA ORIGEN DE LOS PAQUETES -- OK"

# ICMPs redirigidos que pueden alterar la tabla de rutas
for interface in /proc/sys/net/ipv4/conf/*/accept_redirects; do
/bin/echo "0" > ${interface}
done
echo "IMPEDIR ICMPS QUE ALTEREN TABLA DE RUTAS -- OK"
# No guardar registros de los marcianos.
/bin/echo "0" > /proc/sys/net/ipv4/conf/all/log_martians
echo "NO GUARDAR REGISTROS MARCIANOS -- OK"
# Asegurar, aunque no tenga soporte el nucleo, q no hay forward.
/bin/echo "0" > /proc/sys/net/ipv4/ip_forward
echo "ANULAR IP_FORWARD -- OK"


elif [ "$resp" = "d" ]; then
# Habilita pings
/bin/echo "0" > /proc/sys/net/ipv4/icmp_echo_ignore_all
echo "PINGS HABILITADOS -- OK"
# No responder a los broadcast.
/bin/echo "0" > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts
echo "RESPONDER BROADCAST -- OK"
# Para evitar el spoofing la dirección  origen del paquete debe venir del sitio correcto.
for interface in /proc/sys/net/ipv4/conf/*/rp_filter; do
/bin/echo "0" > ${interface}
done
echo "NO VERIFICAR ORIGEN DE LOS PAQUETES -- OK"

# ICMPs redirigidos que pueden alterar la tabla de rutas
for interface in /proc/sys/net/ipv4/conf/*/accept_redirects; do
/bin/echo "1" > ${interface}
done
echo "ACEPTAR ICMPS QUE ALTEREN TABLA DE RUTAS -- OK"
# No guardar registros de los marcianos.
/bin/echo "0" > /proc/sys/net/ipv4/conf/all/log_martians
echo "GUARDAR REGISTROS MARCIANOS -- OK"

elif [ "$resp" = "" ]; then
echo "SIN CAMBIOS -- OK"
elif [ "$resp" != "a" ] || [ "$resp" != "d" ]; then
echo "Opción incorrecta..."
echo ""
fi
