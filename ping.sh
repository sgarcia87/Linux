#!/bin/bash
# Script creado por Sergigm87
# Verifica la conectividad de una dirección IP

if [ -z "$1" ]; then
echo "Indica ip del siguiente modo: bash ping.sh 8.8.8.8"
a=0
else
a=1
fi

if [ "$a" = 1 ]; then
clear
echo "Monitorizando $1"
while :; do
pin=$(ping $1 -c 1 | awk -F ',' '{print $2}' | awk '{print $1}' | sed -n 5p | sed 's/ //g')
if [ "$pin" = 1 ] && [ "$pinant" = 1 ]; then
echo -ne "|"
pinant="1"
elif [ "$pin" = 1 ] && ([ "$pinant" = 0 ]  ||  [ -z "$pinant" ]); then
echo ""
echo "||||||||||||||CONNECTED|||||||||||||"
date
echo -ne "|"
pinant="1"
elif [ "$pin" = 0 ] && ([ "$pinant" = 1 ] || [ -z "$pinant" ]); then
echo ""
echo "------------NOT CONNECTED-----------"
date
echo -ne "-"
pinant="0"
elif [ "$pin" = 0 ] && [ "$pinant" = 0 ]; then
echo -ne "-"
pinant="0"
fi
done
fi
