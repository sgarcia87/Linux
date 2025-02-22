#!/usr/bin/env bash
clear

# -----------------------------------------------------------
# Archivos de configuración
# -----------------------------------------------------------
NODE_LIST_FILE="$HOME/.meshtastic_nodes"
WELCOME_MESSAGE_FILE="$HOME/.meshtastic_welcome_message"

# Crear el fichero de nodos si no existe
if [ ! -f "$NODE_LIST_FILE" ]; then
    echo "Creando la base de datos de nodos detectados..."
    touch "$NODE_LIST_FILE"
fi

# Crear el fichero de mensaje de bienvenida si no existe
if [ ! -f "$WELCOME_MESSAGE_FILE" ]; then
    echo "Bienvenido %s! Pásate por nuestro grupo! https://t.me/MeshtasticGirona" > "$WELCOME_MESSAGE_FILE"
fi

WELCOME_MESSAGE="$(cat "$WELCOME_MESSAGE_FILE")"

# -----------------------------------------------------------
# Función para mostrar el menú principal
# -----------------------------------------------------------
function mostrar_menu() {
    clear
    echo "==============================================="
    echo "               MENÚ DE CONFIGURACIÓN"
    echo "==============================================="
    echo "1) Editar mensaje de bienvenida"
    echo "2) Mostrar mensaje de bienvenida actual"
    echo "3) Iniciar monitorización de la red Meshtastic"
    echo "4) Generar mapa de los nodos con posición"
    echo "5) Salir"
    echo "-----------------------------------------------"
}

# -----------------------------------------------------------
# Función para editar el mensaje de bienvenida
# -----------------------------------------------------------
function editar_mensaje() {
    echo "Mensaje actual: $WELCOME_MESSAGE"
    echo "----------------------------------"
    read -rp "Introduce el nuevo mensaje de bienvenida: " nuevo_mensaje
    echo "$nuevo_mensaje" > "$WELCOME_MESSAGE_FILE"
    WELCOME_MESSAGE="$nuevo_mensaje"
    echo "Mensaje de bienvenida actualizado."
    read -p "Presiona Enter para continuar..."
}

# -----------------------------------------------------------
# Función para mostrar el mensaje de bienvenida actual
# -----------------------------------------------------------
function mostrar_mensaje_actual() {
    echo "Mensaje de bienvenida actual: $WELCOME_MESSAGE"
    read -p "Presiona Enter para continuar..."
}

# -----------------------------------------------------------
# Función para iniciar la monitorización de la red Meshtastic
# -----------------------------------------------------------
function iniciar_monitoreo() {
    trap "echo -e '\nDeteniendo monitorización...'; break" SIGINT

    a=0
    while true; do
        if [ "$a" == "0" ]; then
            echo "Obteniendo información de la red Meshtastic..."
        fi

        # Extraer nombres de nodos (como en tu nuevonodo_v4.sh)
        meshtastic --info | awk -F '"' '
        /"user"/ {
            getline; getline;
            # Dividimos la cuarta columna por "\\u" para quitar emojis en unicode
            split($4, name, "\\\\u");
            print name[1]
        }' > /tmp/current_nodes

        if [ "$a" == "0" ]; then
            echo -e "\n--- Nodos actuales en la red ---"
            cat /tmp/current_nodes
            echo "--------------------------------"
            nNodos=$(cat /tmp/current_nodes | wc -l)
            echo "Nodos totales: $nNodos"
            a=1
        fi

        # Si la base de datos está vacía, guardamos nodos actuales y no enviamos mensajes
        if [ ! -s "$NODE_LIST_FILE" ]; then
            echo "Guardando la lista inicial de nodos..."
            cat /tmp/current_nodes > "$NODE_LIST_FILE"
        else
            # Para cada nodo actual, si no existe en la base de datos, es nuevo
            while read -r node_name; do
                if ! grep -Fxq "$node_name" "$NODE_LIST_FILE"; then
                    echo "🆕 Nuevo nodo detectado: $node_name"
                    meshtastic --sendtext "$(printf "$WELCOME_MESSAGE" "$node_name")"
                    echo "$node_name" >> "$NODE_LIST_FILE"
                    a=0
                fi
            done < /tmp/current_nodes
        fi

        sleep 10
    done

    trap - SIGINT
    echo "Has vuelto al menú principal."
    read -p "Presiona Enter para continuar..."
}

# -----------------------------------------------------------
# Función para generar el mapa con Leaflet
# -----------------------------------------------------------
function generar_mapa() {
    echo "Generando mapa con los nodos que tengan lat/long..."
    # Invocar meshtastic --info para obtener datos
    MESHTASTIC_OUTPUT="$(meshtastic --info 2>/dev/null)"
    if [ -z "$MESHTASTIC_OUTPUT" ]; then
        echo "No se ha recibido salida de meshtastic --info."
        read -p "Presiona Enter para continuar..."
        return
    fi

    IN_NODES=0
    NODE_BLOCK=0
    NAME=""
    LAT=""
    LON=""
    NODES=""

    # Parsear la sección "Nodes in mesh: { ... }"
    while IFS= read -r line; do
      if echo "$line" | grep -q "Nodes in mesh: {"; then
        IN_NODES=1
        continue
      fi
      if [ "$IN_NODES" -eq 1 ] && echo "$line" | grep -q "^Preferences:"; then
        break
      fi
      if [ "$IN_NODES" -eq 0 ]; then
        continue
      fi

      # Inicio de un nodo
      if echo "$line" | grep -Eq '^[[:space:]]*"[^"]+":[[:space:]]*\{$'; then
        NODE_BLOCK=1
        NAME=""
        LAT=""
        LON=""
        continue
      fi

      if [ "$NODE_BLOCK" -eq 1 ]; then
        # longName
        if echo "$line" | grep -q '"longName":'; then
          extracted=$(echo "$line" | sed -n 's/.*"longName": *"\([^"]*\)".*/\1/p')
          if [ -n "$extracted" ]; then
            NAME="$extracted"
          fi
        fi

        # latitude
        if echo "$line" | grep -q '"latitude":'; then
          extracted=$(echo "$line" | sed -n 's/.*"latitude": *\([0-9.\-]*\).*/\1/p')
          if [ -n "$extracted" ]; then
            LAT="$extracted"
          fi
        fi

        # longitude
        if echo "$line" | grep -q '"longitude":'; then
          extracted=$(echo "$line" | sed -n 's/.*"longitude": *\([0-9.\-]*\).*/\1/p')
          if [ -n "$extracted" ]; then
            LON="$extracted"
          fi
        fi

        # Fin de nodo
        if echo "$line" | grep -Eq '^[[:space:]]*\},?[[:space:]]*$'; then
          NODE_BLOCK=0
          if [ -n "$LAT" ] && [ -n "$LON" ]; then
            [ -z "$NAME" ] && NAME="Nodo sin nombre"
            NODES="$NODES
$NAME   $LAT    $LON"
          fi
        fi
      fi
    done <<< "$MESHTASTIC_OUTPUT"

    # Limpiar líneas vacías
    NODES="$(echo "$NODES" | sed '/^[[:space:]]*$/d')"

    echo "DEBUG: Nodos con coordenadas:"
    echo "$NODES"

    # Si no hay nodos con coordenadas, avisamos
    if [ -z "$NODES" ]; then
      echo "No se encontraron nodos con latitud/longitud en la salida."
      read -p "Presiona Enter para continuar..."
      return
    fi

    # Crear HTML
    MAP_FILE="/tmp/meshtastic_map.html"
    FIRST_LINE="$(echo "$NODES" | head -n1)"
    FIRST_NAME="$(echo "$FIRST_LINE" | cut -f1)"
    FIRST_LAT="$( echo "$FIRST_LINE" | cut -f2)"
    FIRST_LON="$( echo "$FIRST_LINE" | cut -f3)"

    cat <<EOF > "$MAP_FILE"
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8" />
  <title>Mapa de nodos Meshtastic</title>
  <!-- Leaflet (sin integrity para evitar bloqueos SRI) -->
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.3/dist/leaflet.css"/>
  <script src="https://unpkg.com/leaflet@1.9.3/dist/leaflet.js"></script>
  <style>
    html, body { margin: 0; padding: 0; height: 100%; }
    #map { width: 100%; height: 100%; }
    .popup-text { font-size: 14px; }
  </style>
</head>
<body>
<div id="map"></div>
<script>
var map = L.map('map').setView([$FIRST_LAT, $FIRST_LON], 10);

L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
  maxZoom: 19,
  attribution: 'Map data © OpenStreetMap contributors'
}).addTo(map);

EOF

    # Añadir marcadores
    echo "$NODES" | while IFS=$'\t' read -r NODE_NAME NODE_LAT NODE_LON; do
      SAFE_NAME="$(echo "$NODE_NAME" | sed "s/'/\\'/g")"
      cat <<EOF >> "$MAP_FILE"
L.marker([$NODE_LAT, $NODE_LON]).addTo(map)
  .bindPopup('<div class="popup-text"><b>$SAFE_NAME</b><br>Lat: $NODE_LAT<br>Lon: $NODE_LON</div>');
EOF
    done

    cat <<EOF >> "$MAP_FILE"
</script>
</body>
</html>
EOF

    echo "Mapa generado en: $MAP_FILE"

    # Intentar abrir el HTML
    if command -v xdg-open &>/dev/null; then
        xdg-open "$MAP_FILE"
    elif command -v open &>/dev/null; then
        open "$MAP_FILE"
    else
        echo "Abre manualmente este archivo en tu navegador: $MAP_FILE"
    fi

    read -p "Presiona Enter para continuar..."
}

# -----------------------------------------------------------
# Bucle principal con menú
# -----------------------------------------------------------
while true; do
    mostrar_menu
    read -rp "Selecciona una opción: " opcion
    case $opcion in
        1)
            editar_mensaje
            ;;
        2)
            mostrar_mensaje_actual
            ;;
        3)
            echo "Iniciando la monitorización de la red Meshtastic..."
            iniciar_monitoreo
            ;;
        4)
            generar_mapa
            ;;
        5)
            echo "Saliendo del script."
            exit 0
            ;;
        *)
            echo "Opción no válida. Inténtalo de nuevo."
            read -p "Presiona Enter para continuar..."
            ;;
    esac
done
