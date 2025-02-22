#!/usr/bin/env bash
clear

# ------------------------------------------------------------------
# Archivos de configuración y variables
# ------------------------------------------------------------------
ARCHIVO_LISTA_NODOS="$HOME/.meshtastic_nodos"
ARCHIVO_MENSAJE_BIENVENIDA="$HOME/.meshtastic_mensaje_bienvenida"

# Variables de ubicación del nodo propietario (en caso de que no se muestren sus coordenadas)
# Ajusta estos valores a tu ubicación real
MI_LATITUD="41.123456"
MI_LONGITUD="2.123456"

# Crear archivos de configuración si no existen
if [ ! -f "$ARCHIVO_LISTA_NODOS" ]; then
    echo "Creando la base de datos de nodos detectados..."
    touch "$ARCHIVO_LISTA_NODOS"
fi

if [ ! -f "$ARCHIVO_MENSAJE_BIENVENIDA" ]; then
    echo "Bienvenido %s! ¡Únete a nuestro grupo! https://t.me/MeshtasticGirona" > "$ARCHIVO_MENSAJE_BIENVENIDA"
fi

MENSAJE_BIENVENIDA="$(cat "$ARCHIVO_MENSAJE_BIENVENIDA")"

# ------------------------------------------------------------------
# Menú principal
# ------------------------------------------------------------------
function mostrar_menu() {
    clear
    banner=$(figlet "Meshtastic" -t)
    echo "$banner"
    echo "==============================================="
    echo "           MENÚ DE CONFIGURACIÓN"
    echo "==============================================="
    echo "1) Mensaje de Bienvenida Automatizado"
    echo "2) Enviar mensaje manual"
    echo "3) Información de nodos"
    echo "4) Ver mapa de nodos"
    echo "-----------------------------------------------"
    echo "5) Salir"
    echo "-----------------------------------------------"
}

# ------------------------------------------------------------------
# 1) Mensaje de Bienvenida Automatizado
# ------------------------------------------------------------------
function mensaje_bienvenida_automatizado() {
    clear
    echo "==============================================="
    echo "     MENSAJE DE BIENVENIDA AUTOMATIZADO"
    echo "==============================================="
    echo "Mensaje de bienvenida actual:"
    echo "----------------------------------"
    echo "$MENSAJE_BIENVENIDA"
    echo "----------------------------------"

    read -rp "¿Deseas editarlo? (s/n): " respuesta
    case "$respuesta" in
        s|S)
            echo
            read -rp "Introduce el nuevo mensaje de bienvenida: " nuevo_mensaje
            echo "$nuevo_mensaje" > "$ARCHIVO_MENSAJE_BIENVENIDA"
            MENSAJE_BIENVENIDA="$nuevo_mensaje"
            echo "Mensaje de bienvenida actualizado."
            ;;
        *)
            echo "No se ha modificado el mensaje de bienvenida."
            ;;
    esac
    echo ""
    read -rp "¿Desea iniciar el envío automático de mensajes a nuevos usuarios? (s/n): " iniciar_auto
    case "$iniciar_auto" in
        s|S)
            echo "Iniciando el envío automático de mensajes de bienvenida..."
            iniciar_monitoreo
            ;;
        *)
            echo "No se iniciará el envío automático."
            ;;
    esac
    read -p "Presiona Enter para continuar..."
}

# ------------------------------------------------------------------
# Función para decodificar secuencias Unicode (para nombres)
# ------------------------------------------------------------------
function decodificar_unicode() {
    python3 -c "import sys, json; print(json.loads(sys.stdin.read().strip()))"
}

# ------------------------------------------------------------------
# Función para iniciar el envío automático de mensajes de bienvenida
# ------------------------------------------------------------------
function iniciar_monitoreo() {
    trap "echo -e '\nDeteniendo envío automático...'; break" SIGINT

    a=0
    while true; do
        if [ "$a" == "0" ]; then
            echo "Obteniendo información de la red Meshtastic..."
        fi

        # Extraer nombres usando awk (igual que en el script original)
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
        if [ ! -s "$ARCHIVO_LISTA_NODOS" ]; then
            echo "Guardando la lista inicial de nodos..."
            cat /tmp/current_nodes > "$ARCHIVO_LISTA_NODOS"
        else
            # Comparamos la lista actual con la base de datos
            while read -r nombre_nodo; do
                if ! grep -Fxq "$nombre_nodo" "$ARCHIVO_LISTA_NODOS"; then
                    echo "🆕 Nuevo nodo detectado: $nombre_nodo"
                    meshtastic --sendtext "$(printf "$MENSAJE_BIENVENIDA" "$nombre_nodo")"
                    echo "$nombre_nodo" >> "$ARCHIVO_LISTA_NODOS"
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
# 2) Enviar mensaje manual
# ------------------------------------------------------------------
function listar_nodos_id() {
    local salida
    salida="$(meshtastic --info 2>/dev/null)"
    [ -z "$salida" ] && return 1

    local en_nodos=0
    local en_nodo=0
    local profundidad=0
    local id_nodo=""
    local nombre_corto=""

    while IFS= read -r linea; do
      if echo "$linea" | grep -q "Nodes in mesh: {"; then
        en_nodos=1
        continue
      fi
      if [ "$en_nodos" -eq 1 ] && echo "$linea" | grep -q "^Preferences:"; then
        break
      fi
      [ "$en_nodos" -eq 0 ] && continue

      if [ "$en_nodo" -eq 0 ] && echo "$linea" | grep -Eoq '^[[:space:]]*"[!][^"]+":[[:space:]]*\{'; then
        en_nodo=1
        profundidad=1
        id_nodo="$(echo "$linea" | sed -n 's/^[[:space:]]*"\(![^"]*\)".*/\1/p')"
        nombre_corto=""
        continue
      fi

      if [ "$en_nodo" -eq 1 ]; then
        opens=$(echo "$linea" | sed 's/[^{}]//g' | tr -cd '{' | wc -c)
        closes=$(echo "$linea" | sed 's/[^{}]//g' | tr -cd '}' | wc -c)
        profundidad=$(( profundidad + opens - closes ))

        if echo "$linea" | grep -q '"shortName":'; then
          local extraido
          extraido="$(echo "$linea" | sed -n 's/.*"shortName": *"\([^"]*\)".*/\1/p')"
          if [ -n "$extraido" ]; then
            nombre_corto="$extraido"
          fi
        fi

        if [ "$profundidad" -le 0 ]; then
          en_nodo=0
          [ -z "$nombre_corto" ] && nombre_corto="(sin shortName)"
          echo "$id_nodo | $nombre_corto"
        fi
      fi
    done <<< "$salida"

    return 0
}

function enviar_mensaje() {
    clear
    echo "¿A quién quieres enviar el mensaje?"
    echo "1) A un nodo concreto (muestra lista Node ID / shortName)"
    echo "2) Al canal por defecto (^all)"
    read -rp "Selecciona una opción [1/2]: " tipo_destino

    echo
    read -rp "Escribe el mensaje a enviar: " mensaje

    case "$tipo_destino" in
        1)
            echo "Lista de nodos detectados (NodeID | shortName):"
            echo "----------------------------------------------"
            listar_nodos_id
            echo "----------------------------------------------"
            echo
            read -rp "Introduce el Node ID de destino (ej: !99c95e76): " id_nodo
            meshtastic --sendtext "$mensaje" --dest "$id_nodo"
            echo "Mensaje enviado al nodo $id_nodo."
            ;;
        2)
            meshtastic --dest '^all' --sendtext "$mensaje"
            echo "Mensaje enviado al canal (^all)."
            ;;
        *)
            echo "Opción no válida. Volviendo al menú."
            ;;
    esac
    read -p "Presiona Enter para continuar..."
}

# ------------------------------------------------------------------
# 3) Información de los nodos
#    - Muestra una tabla con Node ID, Nombre completo (decodificado), Lat, Lon, Alt, Bat, SNR y Hops.
#    - Al finalizar, pregunta si se desea ver el Mapa de nodos.
# ------------------------------------------------------------------
function informacion_nodos() {
    echo "Obteniendo información de los nodos..."
    SALIDA_MESHTASTIC="$(meshtastic --info 2>/dev/null)"
    if [ -z "$SALIDA_MESHTASTIC" ]; then
        echo "No hay salida de 'meshtastic --info'."
        read -p "Presiona Enter para continuar..."
        return
    fi

    # Encabezado de la tabla
    printf "%-12s %-30s %-10s %-10s %-6s %-6s %-6s %-6s\n" "Node ID" "Nombre completo" "Lat" "Lon" "Alt" "Bat" "SNR" "Hops"
    printf '%.0s-' {1..100}
    echo

    en_nodos=0
    en_nodo=0
    profundidad=0
    id_nodo=""
    nombre=""
    lat=""
    lon=""
    alt=""
    bat=""
    snr=""
    hops=""

    while IFS= read -r linea; do
        # Inicia sección de nodos
        if echo "$linea" | grep -q "Nodes in mesh: {"; then
            en_nodos=1
            continue
        fi
        # Fin de la sección de nodos
        if [ "$en_nodos" -eq 1 ] && echo "$linea" | grep -q "^Preferences:"; then
            break
        fi
        [ "$en_nodos" -eq 0 ] && continue

        # Inicio del bloque de un nodo
        if [ "$en_nodo" -eq 0 ] && echo "$linea" | grep -Eoq '^[[:space:]]*"[!][^"]+":[[:space:]]*\{'; then
            en_nodo=1
            profundidad=1
            id_nodo=$(echo "$linea" | sed -n 's/^[[:space:]]*"\(![^"]*\)".*/\1/p')
            nombre=""
            lat=""
            lon=""
            alt=""
            bat=""
            snr=""
            hops=""
            continue
        fi

        if [ "$en_nodo" -eq 1 ]; then
            # Actualización del contador de llaves
            opens=$(echo "$linea" | sed 's/[^{}]//g' | tr -cd '{' | wc -c)
            closes=$(echo "$linea" | sed 's/[^{}]//g' | tr -cd '}' | wc -c)
            profundidad=$(( profundidad + opens - closes ))

            # Extraer longName (preferido) y, si no existe, shortName decodificado
            if echo "$linea" | grep -q '"longName":'; then
                extraido=$(echo "$linea" | sed -n 's/.*"longName": *"\([^"]*\)".*/\1/p')
                if [ -n "$extraido" ]; then
                    nombre=$(printf '"%s"' "$extraido" | decodificar_unicode)
                fi
            fi
            if [ -z "$nombre" ] && echo "$linea" | grep -q '"shortName":'; then
                extraido=$(echo "$linea" | sed -n 's/.*"shortName": *"\([^"]*\)".*/\1/p')
                if [ -n "$extraido" ]; then
                    nombre=$(printf '"%s"' "$extraido" | decodificar_unicode)
                fi
            fi

            # Extraer coordenadas
            if echo "$linea" | grep -q '"latitude":'; then
                extraido=$(echo "$linea" | sed -n 's/.*"latitude": *\([0-9.\-]*\).*/\1/p')
                [ -n "$extraido" ] && lat="$extraido"
            fi
            if echo "$linea" | grep -q '"longitude":'; then
                extraido=$(echo "$linea" | sed -n 's/.*"longitude": *\([0-9.\-]*\).*/\1/p')
                [ -n "$extraido" ] && lon="$extraido"
            fi
            # Altitud (si existe)
            if echo "$linea" | grep -q '"altitude":'; then
                extraido=$(echo "$linea" | sed -n 's/.*"altitude": *\([0-9.\-]*\).*/\1/p')
                [ -n "$extraido" ] && alt="$extraido"
            fi
            # Nivel de batería
            if echo "$linea" | grep -q '"batteryLevel":'; then
                extraido=$(echo "$linea" | sed -n 's/.*"batteryLevel": *\([0-9]*\).*/\1/p')
                [ -n "$extraido" ] && bat="$extraido"
            fi
            # SNR
            if echo "$linea" | grep -q '"snr":'; then
                extraido=$(echo "$linea" | sed -n 's/.*"snr": *\([0-9.\-]*\).*/\1/p')
                [ -n "$extraido" ] && snr="$extraido"
            fi
            # Hops (si existe)
            if echo "$linea" | grep -q '"hopsAway":'; then
                extraido=$(echo "$linea" | sed -n 's/.*"hopsAway": *\([0-9]*\).*/\1/p')
                [ -n "$extraido" ] && hops="$extraido"
            fi

            # Al cerrar el bloque del nodo, imprimir la línea de la tabla
            if [ "$profundidad" -le 0 ]; then
                en_nodo=0
                [ -z "$nombre" ] && nombre="Nodo sin nombre"
                printf "%-12s %-30s %-10s %-10s %-6s %-6s %-6s %-6s\n" "$id_nodo" "$nombre" "$lat" "$lon" "$alt" "$bat" "$snr" "$hops"
            fi
        fi
    done <<< "$SALIDA_MESHTASTIC"

    echo
    read -rp "¿Desea ver el Mapa de nodos? (s/n): " ver_mapa
    if [[ "$ver_mapa" =~ ^[sS]$ ]]; then
        generar_mapa
    else
        read -p "Presiona Enter para continuar..."
    fi
}

# ------------------------------------------------------------------
# 4) Función para generar el mapa
# ------------------------------------------------------------------
function generar_mapa() {
    ARCHIVO_MAPA="/tmp/meshtastic_mapa.html"

    if [ -f "$ARCHIVO_MAPA" ]; then
        echo "Ya existe un mapa creado en: $ARCHIVO_MAPA"
        read -rp "¿Deseas actualizarlo? (s/n): " actualizar
        if [[ "$actualizar" =~ ^[sS]$ ]]; then
            echo "Actualizando el mapa..."
            rm "$ARCHIVO_MAPA"
        else
            echo "Mostrando el mapa existente..."
            if command -v xdg-open &>/dev/null; then
                xdg-open "$ARCHIVO_MAPA"
            elif command -v open &>/dev/null; then
                open "$ARCHIVO_MAPA"
            else
                echo "Abre manualmente el archivo: $ARCHIVO_MAPA"
            fi
            read -p "Presiona Enter para continuar..."
            return
        fi
    fi

    echo "Obteniendo información de Meshtastic y generando mapa..."
    SALIDA_MESHTASTIC="$(meshtastic --info 2>/dev/null)"
    if [ -z "$SALIDA_MESHTASTIC" ]; then
        echo "No hay salida de 'meshtastic --info'."
        read -p "Presiona Enter para continuar..."
        return
    fi

    # Extraer el número de nodo propietario (myNodeNum)
    MI_NUMERO_NODO=$(echo "$SALIDA_MESHTASTIC" | grep -o '"myNodeNum": *[0-9]*' | head -n1 | sed 's/[^0-9]//g')

    en_nodos=0
    en_nodo=0
    profundidad=0
    nombre=""
    lat=""
    lon=""
    num=""
    NODOS=""

    while IFS= read -r linea; do
      if echo "$linea" | grep -q "Nodes in mesh: {"; then
        en_nodos=1
        continue
      fi
      if [ "$en_nodos" -eq 1 ] && echo "$linea" | grep -q "^Preferences:"; then
        break
      fi
      [ "$en_nodos" -eq 0 ] && continue

      if [ "$en_nodo" -eq 0 ] && echo "$linea" | grep -Eoq '^[[:space:]]*"[!][^"]+":[[:space:]]*\{'; then
        en_nodo=1
        profundidad=1
        nombre=""
        lat=""
        lon=""
        num=""
        continue
      fi

      if [ "$en_nodo" -eq 1 ]; then
        if echo "$linea" | grep -q '"num":'; then
            extraido=$(echo "$linea" | sed -n 's/.*"num": *\([0-9]*\).*/\1/p')
            [ -n "$extraido" ] && num="$extraido"
        fi

        opens=$(echo "$linea" | sed 's/[^{}]//g' | tr -cd '{' | wc -c)
        closes=$(echo "$linea" | sed 's/[^{}]//g' | tr -cd '}' | wc -c)
        profundidad=$(( profundidad + opens - closes ))

        if echo "$linea" | grep -q '"shortName":'; then
          extraido=$(echo "$linea" | sed -n 's/.*"shortName": *"\([^"]*\)".*/\1/p')
          [ -n "$extraido" ] && nombre="$extraido"
        fi

        if echo "$linea" | grep -q '"latitude":'; then
          extraido=$(echo "$linea" | sed -n 's/.*"latitude": *\([0-9.\-]*\).*/\1/p')
          [ -n "$extraido" ] && lat="$extraido"
        fi

        if echo "$linea" | grep -q '"longitude":'; then
          extraido=$(echo "$linea" | sed -n 's/.*"longitude": *\([0-9.\-]*\).*/\1/p')
          [ -n "$extraido" ] && lon="$extraido"
        fi

        if [ "$profundidad" -le 0 ]; then
          en_nodo=0
          if { [ -z "$lat" ] || [ -z "$lon" ]; } && [ "$num" = "$MI_NUMERO_NODO" ]; then
              lat="$MI_LATITUD"
              lon="$MI_LONGITUD"
          fi
          if [ -n "$lat" ] && [ -n "$lon" ]; then
            [ -z "$nombre" ] && nombre="Nodo sin nombre"
            NODOS="$NODOS
$nombre	$lat	$lon"
          fi
        fi
      fi
    done <<< "$SALIDA_MESHTASTIC"

    NODOS=$(echo "$NODOS" | sed '/^[[:space:]]*$/d')
    echo "Nodos con coordenadas:"
    echo "$NODOS"

    if [ -z "$NODOS" ]; then
      echo "No se encontraron nodos con latitud/longitud."
      read -p "Presiona Enter para continuar..."
      return
    fi

    PRIMERA_LINEA="$(echo "$NODOS" | head -n1)"
    PRIMER_NOMBRE="$(echo "$PRIMERA_LINEA" | cut -f1)"
    PRIMER_LAT="$(echo "$PRIMERA_LINEA" | cut -f2)"
    PRIMER_LON="$(echo "$PRIMERA_LINEA" | cut -f3)"

    cat <<EOF > "$ARCHIVO_MAPA"
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
var map = L.map('map').setView([$PRIMER_LAT, $PRIMER_LON], 10);
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
  maxZoom: 19,
  attribution: 'Map data © OpenStreetMap contributors'
}).addTo(map);
EOF

    echo "$NODOS" | while IFS=$'\t' read -r NOMBRE_NODE LAT_NODE LON_NODE; do
      NOMBRE_SEGURO="$(echo "$NOMBRE_NODE" | sed "s/'/\\'/g")"
      cat <<EOF >> "$ARCHIVO_MAPA"
L.marker([$LAT_NODE, $LON_NODE]).addTo(map)
  .bindPopup('<div class="popup-text"><b>$NOMBRE_SEGURO</b><br>Lat: $LAT_NODE<br>Lon: $LON_NODE</div>');
EOF
    done

    cat <<EOF >> "$ARCHIVO_MAPA"
</script>
</body>
</html>
EOF

    echo "Mapa generado en: $ARCHIVO_MAPA"
    if command -v xdg-open &>/dev/null; then
        xdg-open "$ARCHIVO_MAPA"
    elif command -v open &>/dev/null; then
        open "$ARCHIVO_MAPA"
    else
        echo "Abre manualmente el archivo: $ARCHIVO_MAPA"
    fi
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
            mensaje_bienvenida_automatizado
            ;;
        2)
            enviar_mensaje
            ;;
        3)
            informacion_nodos
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
