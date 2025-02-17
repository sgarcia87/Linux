#!/usr/bin/env bash
clear

# ------------------------------------------------------------------
# Ficheros de configuración
# ------------------------------------------------------------------
NODE_LIST_FILE="$HOME/.meshtastic_nodes"
WELCOME_MESSAGE_FILE="$HOME/.meshtastic_welcome_message"

# Crear si no existen
if [ ! -f "$NODE_LIST_FILE" ]; then
    echo "Creando la base de datos de nodos detectados..."
    touch "$NODE_LIST_FILE"
fi

if [ ! -f "$WELCOME_MESSAGE_FILE" ]; then
    echo "Bienvenido %s! Pásate por nuestro grupo! https://t.me/MeshtasticGirona" > "$WELCOME_MESSAGE_FILE"
fi

WELCOME_MESSAGE="$(cat "$WELCOME_MESSAGE_FILE")"

# ------------------------------------------------------------------
# Menú principal
# ------------------------------------------------------------------
function mostrar_menu() {
    clear
    echo "==============================================="
    echo "           MENÚ DE CONFIGURACIÓN"
    echo "==============================================="
    echo "1) Configurar mensaje de bienvenida"
    echo "2) Iniciar monitorización de la red Meshtastic"
    echo "3) Generar mapa de nodos"
    echo "4) Enviar mensaje manual"
    echo "5) Salir"
    echo "-----------------------------------------------"
}

# ------------------------------------------------------------------
# 1) Configurar mensaje de bienvenida
#    - Muestra el mensaje
#    - Pregunta si quieres editarlo (s/n)
# ------------------------------------------------------------------
function configurar_mensaje_bienvenida() {
    echo "Mensaje de bienvenida actual:"
    echo "----------------------------------"
    echo "$WELCOME_MESSAGE"
    echo "----------------------------------"

    read -rp "¿Deseas editarlo? (s/n): " respuesta
    case "$respuesta" in
        s|S)
            echo
            read -rp "Introduce el nuevo mensaje de bienvenida: " nuevo_mensaje
            echo "$nuevo_mensaje" > "$WELCOME_MESSAGE_FILE"
            WELCOME_MESSAGE="$nuevo_mensaje"
            echo "Mensaje de bienvenida actualizado."
            ;;
        *)
            echo "No se ha modificado el mensaje de bienvenida."
            ;;
    esac
    read -p "Presiona Enter para continuar..."
}

# ------------------------------------------------------------------
# 2) Iniciar monitorización de la red Meshtastic
# ------------------------------------------------------------------
function iniciar_monitoreo() {
    trap "echo -e '\nDeteniendo monitorización...'; break" SIGINT

    a=0
    while true; do
        if [ "$a" == "0" ]; then
            echo "Obteniendo información de la red Meshtastic..."
        fi

        # Extraer nombres con awk (como en tu script original)
        meshtastic --info | awk -F '"' '
        /"user"/ {
            getline; getline;
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

        # Si la base de datos está vacía, guardamos sin enviar
        if [ ! -s "$NODE_LIST_FILE" ]; then
            echo "Guardando la lista inicial de nodos..."
            cat /tmp/current_nodes > "$NODE_LIST_FILE"
        else
            # Comparamos
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

# ------------------------------------------------------------------
# 3) Generar mapa (shortName + lat/long) con conteo de llaves
# ------------------------------------------------------------------
function generar_mapa() {
    echo "Obteniendo información de Meshtastic y generando mapa..."
    MESHTASTIC_OUTPUT="$(meshtastic --info 2>/dev/null)"
    if [ -z "$MESHTASTIC_OUTPUT" ]; then
        echo "No hay salida de 'meshtastic --info'."
        read -p "Presiona Enter para continuar..."
        return
    fi

    IN_NODES=0
    IN_NODE=0
    DEPTH=0

    NAME=""
    LAT=""
    LON=""
    NODES=""

    while IFS= read -r line; do
      if echo "$line" | grep -q "Nodes in mesh: {"; then
        IN_NODES=1
        continue
      fi
      if [ "$IN_NODES" -eq 1 ] && echo "$line" | grep -q "^Preferences:"; then
        break
      fi
      [ "$IN_NODES" -eq 0 ] && continue

      if [ "$IN_NODE" -eq 0 ] && echo "$line" | grep -Eq '^[[:space:]]*"[^"]+":[[:space:]]*\{$'; then
        IN_NODE=1
        DEPTH=1
        NAME=""
        LAT=""
        LON=""
        continue
      fi

      if [ "$IN_NODE" -eq 1 ]; then
        # Contar llaves
        opens=$(echo "$line" | sed 's/[^{}]//g' | tr -cd '{' | wc -c)
        closes=$(echo "$line" | sed 's/[^{}]//g' | tr -cd '}' | wc -c)
        DEPTH=$(( DEPTH + opens - closes ))

        # shortName
        if echo "$line" | grep -q '"shortName":'; then
          extracted=$(echo "$line" | sed -n 's/.*"shortName": *"[^"]*".*/\1/p')
          if [ -n "$extracted" ]; then
            NAME="$extracted"
          fi
        fi

        # latitude
        if echo "$line" | grep -q '"latitude":'; then
          extracted=$(echo "$line" | sed -n 's/.*"latitude": *[0-9.\-]*.*/\1/p')
          [ -n "$extracted" ] && LAT="$extracted"
        fi

        # longitude
        if echo "$line" | grep -q '"longitude":'; then
          extracted=$(echo "$line" | sed -n 's/.*"longitude": *[0-9.\-]*.*/\1/p')
          [ -n "$extracted" ] && LON="$extracted"
        fi

        if [ "$DEPTH" -le 0 ]; then
          IN_NODE=0
          if [ -n "$LAT" ] && [ -n "$LON" ]; then
            [ -z "$NAME" ] && NAME="Nodo sin nombre"
            NODES="$NODES
$NAME	$LAT	$LON"
          fi
        fi
      fi
    done <<< "$MESHTASTIC_OUTPUT"

    NODES="$(echo "$NODES" | sed '/^[[:space:]]*$/d')"
    echo "Nodos con coordenadas:"
    echo "$NODES"

    if [ -z "$NODES" ]; then
      echo "No se encontraron nodos con latitud/longitud."
      read -p "Presiona Enter para continuar..."
      return
    fi

    # Generamos HTML
    FIRST_LINE="$(echo "$NODES" | head -n1)"
    FIRST_NAME="$(echo "$FIRST_LINE" | cut -f1)"
    FIRST_LAT="$(echo "$FIRST_LINE" | cut -f2)"
    FIRST_LON="$(echo "$FIRST_LINE" | cut -f3)"
    MAP_FILE="/tmp/meshtastic_map.html"

    cat <<EOF > "$MAP_FILE"
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8" />
  <title>Mapa de nodos Meshtastic</title>
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

    if command -v xdg-open &>/dev/null; then
        xdg-open "$MAP_FILE"
    elif command -v open &>/dev/null; then
        open "$MAP_FILE"
    else
        echo "Abre manualmente el archivo: $MAP_FILE"
    fi

    read -p "Presiona Enter para continuar..."
}

# ------------------------------------------------------------------
# 4) Enviar mensaje manual
#    - Opción 1: a un nodo (muestra IDs/nombres, user elige)
#    - Opción 2: al canal ( '^all' )
# ------------------------------------------------------------------

# a) Listar nodos con su ID y shortName (o longName si prefieres)
function listar_nodos_id() {
    # Usamos un método similar (conteo de llaves)
    # Pero aquí buscaremos "id": "!xxxx" y "shortName"
    local output
    output="$(meshtastic --info 2>/dev/null)"
    [ -z "$output" ] && return 1

    local in_nodes=0
    local in_node=0
    local depth=0
    local node_id=""
    local short_name=""

    while IFS= read -r line; do
      if echo "$line" | grep -q "Nodes in mesh: {"; then
        in_nodes=1
        continue
      fi
      if [ "$in_nodes" -eq 1 ] && echo "$line" | grep -q "^Preferences:"; then
        break
      fi
      [ "$in_nodes" -eq 0 ] && continue

      # Nuevo nodo
      if [ "$in_node" -eq 0 ] && echo "$line" | grep -Eoq '^[[:space:]]*"[!][^"]+":[[:space:]]*\{'; then
        in_node=1
        depth=1
        # Extraer ID del nodo
        node_id="$(echo "$line" | sed -n 's/^[[:space:]]*"![^"]*".*/\1/p')"
        short_name=""
        continue
      fi

      if [ "$in_node" -eq 1 ]; then
        opens=$(echo "$line" | sed 's/[^{}]//g' | tr -cd '{' | wc -c)
        closes=$(echo "$line" | sed 's/[^{}]//g' | tr -cd '}' | wc -c)
        depth=$(( depth + opens - closes ))

        # shortName
        if echo "$line" | grep -q '"shortName":'; then
          local extracted
          extracted="$(echo "$line" | sed -n 's/.*"shortName": *"[^"]*".*/\1/p')"
          if [ -n "$extracted" ]; then
            short_name="$extracted"
          fi
        fi

        if [ "$depth" -le 0 ]; then
          # Cerramos nodo
          in_node=0
          [ -z "$short_name" ] && short_name="(sin shortName)"
          # Imprimir
          echo "$node_id | $short_name"
        fi
      fi
    done <<< "$output"

    return 0
}

function enviar_mensaje() {
    clear
    echo "¿A quién quieres enviar el mensaje?"
    echo "1) A un nodo concreto (muestra lista Node ID / shortName)"
    echo "2) Al canal por defecto (^all)"
    read -rp "Selecciona una opción [1/2]: " tipo_dest

    echo
    # Mensaje
    read -rp "Escribe el mensaje a enviar: " mensaje

    case "$tipo_dest" in
        1)
            echo "Lista de nodos detectados (NodeID | shortName):"
            echo "----------------------------------------------"
            listar_nodos_id
            echo "----------------------------------------------"
            echo
            read -rp "Introduce el Node ID de destino (ej: !99c95e76): " node_id
            meshtastic --dest "$node_id" --sendtext "$mensaje"
            echo "Mensaje enviado al nodo $node_id."
            ;;
        2)
            meshtastic --dest '^all' --sendtext "$mensaje"
            echo "Mensaje enviado al canal ( ^all )."
            ;;
        *)
            echo "Opción no válida. Volviendo al menú."
            ;;
    esac
    read -p "Presiona Enter para continuar..."
}

# ------------------------------------------------------------------
# Bucle principal
# ------------------------------------------------------------------
while true; do
    mostrar_menu
    read -rp "Selecciona una opción: " opcion
    case $opcion in
        1)
            configurar_mensaje_bienvenida
            ;;
        2)
            echo "Iniciando la monitorización de la red Meshtastic..."
            iniciar_monitoreo
            ;;
        3)
            generar_mapa
            ;;
        4)
            enviar_mensaje
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
