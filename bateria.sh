#!/bin/bash

# Solicitar al usuario el ID del nodo
read -p "Introduce el ID del nodo a monitorizar (ejemplo: 43314718): " NODE_ID

# Solicitar al usuario el intervalo en minutos
read -p "Introduce el intervalo de tiempo en minutos para solicitar la información: " INTERVAL_MINUTES

# Convertir el intervalo a segundos
INTERVAL_SECONDS=$((INTERVAL_MINUTES * 60))

# Preguntar si la conexión es vía Wi-Fi
read -p "¿Te conectas al nodo vía Wi-Fi? (s/n): " WIFI_OPTION

# Inicializar la variable de host
HOST_OPTION=""

if [[ "$WIFI_OPTION" == "s" || "$WIFI_OPTION" == "S" ]]; then
    read -p "Introduce la dirección IP del nodo: " NODE_IP
    HOST_OPTION="--host $NODE_IP"
fi

# Nombre del archivo de registro
LOG_FILE="registro_bateria_${NODE_ID}.txt"

echo "Iniciando monitorización del nodo $NODE_ID cada $INTERVAL_MINUTES minutos..."
echo "Los datos se guardarán en el archivo $LOG_FILE"

# Bucle infinito para solicitar telemetría en el intervalo especificado
while true; do
    # Obtener la fecha y hora actual
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    # Ejecutar el comando de solicitud de telemetría
    OUTPUT=$(meshtastic $HOST_OPTION --request-telemetry --dest $NODE_ID 2>&1)

    # Extraer el nivel de batería y el voltaje de la salida
    BATTERY_LEVEL=$(echo "$OUTPUT" | grep "Battery level" | awk '{print $3}')
    VOLTAGE=$(echo "$OUTPUT" | grep "Voltage" | awk '{print $2}')

    # Verificar si se obtuvieron los datos correctamente
    if [[ -n "$BATTERY_LEVEL" && -n "$VOLTAGE" ]]; then
        # Guardar los datos en el archivo de registro
        echo "$TIMESTAMP - Nivel de batería: $BATTERY_LEVEL - Voltaje: $VOLTAGE" >> "$LOG_FILE"
        echo "[$TIMESTAMP] Datos registrados correctamente."
    else
        echo "[$TIMESTAMP] Error al obtener los datos de telemetría."
        echo "$OUTPUT"
    fi

    # Esperar el intervalo especificado antes de la siguiente solicitud
    sleep $INTERVAL_SECONDS
done
