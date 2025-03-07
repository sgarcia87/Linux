#!/usr/bin/env bash
clear

# ------------------------------------------------------------------
# Definir variables de colores y emoticonos
# ------------------------------------------------------------------
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
BLUE='\e[34m'
PURPLE='\e[35m'
CYAN='\e[36m'
NC='\e[0m'         # Sin color
BOLD='\e[1m'

# Emoticonos
WARN="⚠️  "
INFO="ℹ️  "
SUCCESS="✅  "
QUESTION="❓  "
NOTE="📝  "
MAG="🔍  "

# ------------------------------------------------------------------
# Comprobar uso del dispositivo USB (/dev/ttyUSB0)
# ------------------------------------------------------------------
usb_usage=$(lsof /dev/ttyUSB0 2>/dev/null)
if [ -n "$usb_usage" ]; then
    echo -e "${RED}${BOLD}${WARN} AVISO: El dispositivo USB (/dev/ttyUSB0) está siendo usado por el siguiente proceso:${NC}"
    echo -e "${YELLOW}$usb_usage${NC}"
    sleep 5
fi

# ------------------------------------------------------------------
# Ficheros de configuración y variables
# ------------------------------------------------------------------
NODE_LIST_FILE=".meshtastic_nodes"
WELCOME_MESSAGE_FILE=".meshtastic_welcome_message"

# Configuración para la conexión vía WIFI
MY_IP="" 	# Ej: 192.168.1.40

# Variables de ubicación del nodo propietario (si no aparecen sus coordenadas)
MY_LAT="41.855278"    # Tu latitud (origen)
MY_LON="2.734722"     # Tu longitud (origen)
MAX_ATTEMPTS=1        # Número máximo de intentos para cada traceroute
MAP_FILE="/tmp/meshtastic_map.html"

# Archivos de caché para traceroute
TRACEROUTE_COORDS_CACHE="/tmp/traceroute_coords.json"
TRACEROUTE_ROUTES_CACHE="/tmp/traceroute_routes.json"

# Crear archivos de configuración si no existen
if [ ! -f "$NODE_LIST_FILE" ]; then
    echo -e "${CYAN}${BOLD}${INFO} Creando la base de datos de nodos detectados...${NC}"
    touch "$NODE_LIST_FILE"
fi

if [ ! -f "$WELCOME_MESSAGE_FILE" ]; then
    echo "Bienvenido %s! Pásate por nuestro grupo! https://t.me/MeshtasticGirona" > "$WELCOME_MESSAGE_FILE"
fi

WELCOME_MESSAGE="$(cat "$WELCOME_MESSAGE_FILE")"

# ------------------------------------------------------------------
# Función de configuración
# ------------------------------------------------------------------
function configuracion() {
    clear
    banner=$(figlet "Meshtastic" -t)
    echo -e "${PURPLE}${BOLD}$banner${NC}"
    echo -e "${BLUE}${BOLD}===============================================${NC}"
    echo -e "${BLUE}${BOLD}           MENÚ DE CONFIGURACIÓN ${NC}"
    echo -e "${BLUE}${BOLD}===============================================${NC}"
    echo -e "1) Configurar posición GPS de tu nodo."
    echo -e "2) Configurar conexión vía WIFI."
    echo -e "3) Volver al menú principal."
    echo -e "${BLUE}${BOLD}===============================================${NC}"
    read -rp "${QUESTION} Selecciona una opción: " respuesta
    case "$respuesta" in
       1)
            configuracion_1
            ;;
       2)
            configuracion_2
            ;;
       3)
            echo -e "${GREEN}${SUCCESS} Volviendo al Menú principal.${NC}"
            ;;
        *)
            echo -e "${RED}${WARN} Opción no válida. Inténtalo de nuevo.${NC}"
            read -p "Presiona Enter para continuar..."
            ;;
    esac
}

# ------------------------------------------------------------------
# Función de configuración 1: LAT/LON
# ------------------------------------------------------------------
function configuracion_1() {
    clear
    banner=$(figlet "Meshtastic" -t)
    echo -e "${PURPLE}${BOLD}$banner${NC}"
    echo -e "${BLUE}${BOLD}===============================================${NC}"
    echo -e "${BLUE}${BOLD}       MENÚ DE CONFIGURACIÓN LAT/LON${NC}"
    echo -e "${BLUE}${BOLD}===============================================${NC}"
    echo -e "${INFO} Indica LATITUD y LONGITUD de tu nodo."
    echo -e "${NOTE} En caso de no aparecer tus coordenadas se usarán estas:"
    echo -e "   ${YELLOW}LAT: $MY_LAT ${NC} , ${YELLOW}LON: $MY_LON${NC}"
    echo -e "${BLUE}${BOLD}===============================================${NC}"
    read -p "${QUESTION} Indica la LATITUD: " MY_LAT
    read -p "${QUESTION} Indica la LONGITUD: " MY_LON 
}

# ------------------------------------------------------------------
# Función de configuración 2: WIFI
# ------------------------------------------------------------------
function configuracion_2() {
    clear
    banner=$(figlet "Meshtastic" -t)
    echo -e "${PURPLE}${BOLD}$banner${NC}"
    echo -e "${BLUE}${BOLD}===============================================${NC}"
    echo -e "${BLUE}${BOLD}       MENÚ DE CONFIGURACIÓN WIFI${NC}"
    echo -e "${BLUE}${BOLD}===============================================${NC}"
    echo -e "${INFO} ¿Quieres activar la conexión vía wifi? (s/n)"
    read -rp "${QUESTION} Indica s/n: " respuesta
    if [ "$respuesta" == "s" ] || [ "$respuesta" == "S" ]; then
        echo -e "${INFO} Indicar la IP de tu nodo. (actual: ${YELLOW}$MY_IP${NC})"
        read -p "${QUESTION} Indica la IP: " MY_IP
    else
        MY_IP=""
    fi
}

# ------------------------------------------------------------------
# Función automatizada: usuarios y mapa de traceroute
# ------------------------------------------------------------------
auto() {
    clear
    banner=$(figlet "Meshtastic" -t)
    echo -e "${PURPLE}${BOLD}$banner${NC}"
    echo -e "${BLUE}${BOLD}===============================================${NC}"
    echo -e "${BLUE}${BOLD} BUSCA USUARIOS NUEVOS Y REALIZA TRACEROUTES${NC}"
    echo -e "${BLUE}${BOLD}===============================================${NC}"
    echo ""
    iniciar_monitoreo auto
    echo ""
    generar_mapa auto
    echo ""
}

# ------------------------------------------------------------------
# Menú principal
# ------------------------------------------------------------------
function mostrar_menu() {
    clear
    banner=$(figlet "Meshtastic" -t)
    echo -e "${PURPLE}${BOLD}$banner${NC}"
    echo -e "${BLUE}${BOLD}===============================================${NC}"
    echo -e "${BLUE}${BOLD}           MENÚ PRINCIPAL${NC}"
    echo -e "${BLUE}${BOLD}===============================================${NC}"
    echo -e "0) Bucle automatizado (opción 1 y 4)"
    echo -e "1) Mensaje de Bienvenida Automatizado"
    echo -e "2) Enviar mensaje manual"
    echo -e "3) Información de nodos"
    echo -e "4) Ver mapa de nodos"
    echo -e "${BLUE}${BOLD}===============================================${NC}"
    echo -e "5) Configuración"
    echo -e "6) Salir"
    echo -e "${BLUE}${BOLD}===============================================${NC}"
}

# ------------------------------------------------------------------
# 1) Mensaje de Bienvenida Automatizado
# ------------------------------------------------------------------
function mensaje_bienvenida_automatizado() {
    clear
    echo -e "${BLUE}${BOLD}===============================================${NC}"
    echo -e "${BLUE}${BOLD}     MENSAJE DE BIENVENIDA AUTOMATIZADO${NC}"
    echo -e "${BLUE}${BOLD}===============================================${NC}"
    echo -e "${INFO} Mensaje de bienvenida actual:"
    echo -e "${YELLOW}----------------------------------${NC}"
    echo -e "$WELCOME_MESSAGE"
    echo -e "${YELLOW}----------------------------------${NC}"

    read -rp "${QUESTION} ¿Deseas editarlo? (s/n): " respuesta
    case "$respuesta" in
        s|S)
            echo
            read -rp "${QUESTION} Introduce el nuevo mensaje de bienvenida: " nuevo_mensaje
            echo "$nuevo_mensaje" > "$WELCOME_MESSAGE_FILE"
            WELCOME_MESSAGE="$nuevo_mensaje"
            echo -e "${GREEN}${SUCCESS} Mensaje de bienvenida actualizado.${NC}"
            ;;
        *)
            echo -e "${INFO} No se ha modificado el mensaje de bienvenida."
            ;;
    esac
    echo ""
    read -rp "${QUESTION} ¿Desea iniciar el envío automático de mensajes a nuevos usuarios? (s/n): " iniciar_auto
    case "$iniciar_auto" in
        s|S)
            echo -e "${INFO} Iniciando el envío automático de mensajes de bienvenida..."
            iniciar_monitoreo
            ;;
        *)
            echo -e "${INFO} No se iniciará el envío automático."
            ;;
    esac
    read -p "Presiona Enter para continuar..."
}

# ------------------------------------------------------------------
# Función para decodificar secuencias Unicode (para nombres)
# ------------------------------------------------------------------
function decode_unicode() {
    python3 -c "import sys, json; print(json.loads(sys.stdin.read().strip()))"
}

# ------------------------------------------------------------------
# Función para iniciar el envío automático de mensajes de bienvenida
# ------------------------------------------------------------------
function iniciar_monitoreo() {
    ORIGEN="$1"
    trap "echo -e '\n${RED}${WARN} Deteniendo envío automático...${NC}'; break" SIGINT

    a=0
    while true; do
        if [ "$a" == "0" ]; then
            echo -e "${CYAN}${INFO} Obteniendo información de la red Meshtastic...${NC}"
        fi

        if [ -n "$MY_IP" ]; then
            meshtastic --host "$MY_IP" --info | awk -F '"' '
            /"user"/ {
                getline; getline;
                split($4, name, "\\\\u");
                print name[1]
            }' > /tmp/current_nodes
        else
            meshtastic --info | awk -F '"' '
            /"user"/ {
                getline; getline;
                split($4, name, "\\\\u");
                print name[1]
            }' > /tmp/current_nodes
        fi

        if [ "$a" == "0" ]; then
            echo -e "\n${YELLOW}${BOLD}--- Nodos actuales en la red ---${NC}"
            cat /tmp/current_nodes
            echo -e "${YELLOW}--------------------------------${NC}"
            nNodos=$(cat /tmp/current_nodes | wc -l)
            echo -e "${INFO} Nodos totales: ${YELLOW}$nNodos${NC}"
            a=1
        fi

        if [ ! -s "$NODE_LIST_FILE" ]; then
            echo -e "${CYAN}${INFO} Guardando la lista inicial de nodos...${NC}"
            cat /tmp/current_nodes > "$NODE_LIST_FILE"
        else
            while read -r node_name; do
                if ! grep -Fxq "$node_name" "$NODE_LIST_FILE"; then
                    echo -e "${GREEN}${SUCCESS} 🆕 Nuevo nodo detectado: ${YELLOW}$node_name${NC}"
                    if [ -n "$MY_IP" ]; then
                        meshtastic --host "$MY_IP" --sendtext "$(printf "$WELCOME_MESSAGE" "$node_name")"
                    else
                        meshtastic --sendtext "$(printf "$WELCOME_MESSAGE" "$node_name")"
                    fi
                    echo "$node_name" >> "$NODE_LIST_FILE"
                    a=0
                fi
            done < /tmp/current_nodes
        fi

        if [ "$ORIGEN" == "auto" ]; then
            break
        fi
        
        sleep 10
    done

    trap - SIGINT
}

# ------------------------------------------------------------------
# 2) Enviar mensaje manual
# ------------------------------------------------------------------
function listar_nodos_id() {
    local output
    if [ -n "$MY_IP" ]; then
        output="$(meshtastic --host "$MY_IP" --info 2>/dev/null)"
    else
        output="$(meshtastic --info 2>/dev/null)"
    fi
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

      if [ "$in_node" -eq 0 ] && echo "$line" | grep -Eoq '^[[:space:]]*"[!][^"]+":[[:space:]]*\{'; then
        in_node=1
        depth=1
        node_id="$(echo "$line" | sed -n 's/^[[:space:]]*"\(![^"]*\)".*/\1/p')"
        short_name=""
        continue
      fi

      if [ "$in_node" -eq 1 ]; then
        opens=$(echo "$line" | sed 's/[^{}]//g' | tr -cd '{' | wc -c)
        closes=$(echo "$line" | sed 's/[^{}]//g' | tr -cd '}' | wc -c)
        depth=$(( depth + opens - closes ))

        if echo "$line" | grep -q '"shortName":'; then
          local extracted
          extracted="$(echo "$line" | sed -n 's/.*"shortName": *"\([^"]*\)".*/\1/p')"
          if [ -n "$extracted" ]; then
            short_name="$extracted"
          fi
        fi

        if [ "$depth" -le 0 ]; then
          in_node=0
          [ -z "$short_name" ] && short_name="(sin shortName)"
          echo -e "${YELLOW}$node_id${NC} | ${CYAN}$short_name${NC}"
        fi
      fi
    done <<< "$output"

    return 0
}

function enviar_mensaje() {
    clear
    echo -e "${INFO} ¿A quién quieres enviar el mensaje?"
    echo -e "1) A un nodo concreto (muestra lista Node ID / shortName)"
    echo -e "2) Al canal por defecto (^all)"
    read -rp "${QUESTION} Selecciona una opción [1/2]: " tipo_dest

    echo
    read -rp "${QUESTION} Escribe el mensaje a enviar: " mensaje

    case "$tipo_dest" in
        1)
            echo -e "${INFO} Lista de nodos detectados (NodeID | shortName):"
            echo -e "${YELLOW}----------------------------------------------${NC}"
            listar_nodos_id
            echo -e "${YELLOW}----------------------------------------------${NC}"
            echo
            read -rp "${QUESTION} Introduce el Node ID de destino (ej: !99c95e76): " node_id
            if [ -n "$MY_IP" ]; then
                meshtastic --host "$MY_IP" --sendtext "$mensaje" --dest "$node_id"
            else
                meshtastic --sendtext "$mensaje" --dest "$node_id"
            fi
            echo -e "${GREEN}${SUCCESS} Mensaje enviado al nodo ${YELLOW}$node_id${NC}."
            ;;
        2)
            if [ -n "$MY_IP" ]; then     
                meshtastic --host "$MY_IP" --dest '^all' --sendtext "$mensaje"
            else
                meshtastic --dest '^all' --sendtext "$mensaje"
            fi
            echo -e "${GREEN}${SUCCESS} Mensaje enviado al canal (^all).${NC}"
            ;;
        *)
            echo -e "${RED}${WARN} Opción no válida. Volviendo al menú.${NC}"
            ;;
    esac
    read -p "Presiona Enter para continuar..."
}

# ------------------------------------------------------------------
# 3) Información de los nodos
# ------------------------------------------------------------------
function informacion_nodos() {
    echo -e "${CYAN}${INFO} Obteniendo información de los nodos...${NC}"
    if [ -n "$MY_IP" ]; then     
        MESHTASTIC_OUTPUT="$(meshtastic --host "$MY_IP" --info 2>/dev/null)"
    else
        MESHTASTIC_OUTPUT="$(meshtastic --info 2>/dev/null)"
    fi
    if [ -z "$MESHTASTIC_OUTPUT" ]; then
        echo -e "${RED}${WARN} No hay salida de 'meshtastic --info'.${NC}"
        read -p "Presiona Enter para continuar..."
        return
    fi

    mostrar_tabla() {
        printf "%-12s %-30s %-10s %-10s %-6s %-6s %-6s %-6s\n" "Node ID" "Nombre completo" "Lat" "Lon" "Alt" "Bat" "SNR" "Hops"
        printf '%.0s-' {1..100}
        echo

        IN_NODES=0
        IN_NODE=0
        DEPTH=0
        NODE_ID=""
        NAME=""
        LAT=""
        LON=""
        ALT=""
        BAT=""
        SNR=""
        HOPS=""

        while IFS= read -r line; do
            if echo "$line" | grep -q "Nodes in mesh: {"; then
                IN_NODES=1
                continue
            fi
            if [ "$IN_NODES" -eq 1 ] && echo "$line" | grep -q "^Preferences:"; then
                break
            fi
            [ "$IN_NODES" -eq 0 ] && continue

            if [ "$IN_NODE" -eq 0 ] && echo "$line" | grep -Eoq '^[[:space:]]*"[!][^"]+":[[:space:]]*\{'; then
                IN_NODE=1
                DEPTH=1
                NODE_ID=$(echo "$line" | sed -n 's/^[[:space:]]*"\(![^"]*\)".*/\1/p')
                NAME=""
                LAT=""
                LON=""
                ALT=""
                BAT=""
                SNR=""
                HOPS=""
                continue
            fi
            if [ "$IN_NODE" -eq 1 ]; then
                opens=$(echo "$line" | sed 's/[^{}]//g' | tr -cd '{' | wc -c)
                closes=$(echo "$line" | sed 's/[^{}]//g' | tr -cd '}' | wc -c)
                DEPTH=$(( DEPTH + opens - closes ))
                if echo "$line" | grep -q '"longName":'; then
                    extracted=$(echo "$line" | sed -n 's/.*"longName": *"\([^"]*\)".*/\1/p')
                    if [ -n "$extracted" ]; then
                        NAME=$(printf '"%s"' "$extracted" | decode_unicode)
                    fi
                fi
                if [ -z "$NAME" ] && echo "$line" | grep -q '"shortName":'; then
                    extracted=$(echo "$line" | sed -n 's/.*"shortName": *"\([^"]*\)".*/\1/p')
                    if [ -n "$extracted" ]; then
                        NAME=$(printf '"%s"' "$extracted" | decode_unicode)
                    fi
                fi

                if echo "$line" | grep -q '"latitude":'; then
                    extracted=$(echo "$line" | sed -n 's/.*"latitude": *\([0-9.\-]*\).*/\1/p')
                    [ -n "$extracted" ] && LAT="$extracted"
                fi
                if echo "$line" | grep -q '"longitude":'; then
                    extracted=$(echo "$line" | sed -n 's/.*"longitude": *\([0-9.\-]*\).*/\1/p')
                    [ -n "$extracted" ] && LON="$extracted"
                fi
                if echo "$line" | grep -q '"altitude":'; then
                    extracted=$(echo "$line" | sed -n 's/.*"altitude": *\([0-9.\-]*\).*/\1/p')
                    [ -n "$extracted" ] && ALT="$extracted"
                fi
                if echo "$line" | grep -q '"batteryLevel":'; then
                    extracted=$(echo "$line" | sed -n 's/.*"batteryLevel": *\([0-9]*\).*/\1/p')
                    [ -n "$extracted" ] && BAT="$extracted"
                fi
                if echo "$line" | grep -q '"snr":'; then
                    extracted=$(echo "$line" | sed -n 's/.*"snr": *\([0-9.\-]*\).*/\1/p')
                    [ -n "$extracted" ] && SNR="$extracted"
                fi
                if echo "$line" | grep -q '"hopsAway":'; then
                    extracted=$(echo "$line" | sed -n 's/.*"hopsAway": *\([0-9]*\).*/\1/p')
                    [ -n "$extracted" ] && HOPS="$extracted"
                fi

                if [ "$DEPTH" -le 0 ]; then
                    IN_NODE=0
                    [ -z "$NAME" ] && NAME="Nodo sin nombre"
                    printf "%-12s %-30s %-10s %-10s %-6s %-6s %-6s %-6s\n" "$NODE_ID" "$NAME" "$LAT" "$LON" "$ALT" "$BAT" "$SNR" "$HOPS"
                fi
            fi
        done <<< "$MESHTASTIC_OUTPUT"
    }

    mostrar_tabla

    echo ""
    read -rp "${QUESTION} ¿Desea activar el bucle de actualización de nodos cada 5 minutos? (s/n): " activar_bucle
    if [[ "$activar_bucle" =~ ^[sS]$ ]]; then
        echo -e "${INFO} Presiona CTRL+C para detener la actualización y regresar al menú principal.${NC}"
        trap 'echo ""; echo -e "${RED}${WARN} Bucle interrumpido. Regresando al menú...${NC}"; break' SIGINT
        while true; do
            clear
            echo -e "${CYAN}${INFO} Actualizando información de nodos...${NC}"
            if [ -n "$MY_IP" ]; then     
                MESHTASTIC_OUTPUT="$(meshtastic --host "$MY_IP" --info 2>/dev/null)"
            else
                MESHTASTIC_OUTPUT="$(meshtastic --info 2>/dev/null)"
            fi
            if [ -n "$MESHTASTIC_OUTPUT" ]; then
                mostrar_tabla
            else
                echo -e "${RED}${WARN} No hay salida de 'meshtastic --info'.${NC}"
            fi
            echo -e "${INFO} Actualización completada. Esperando 5 minutos para la siguiente actualización...${NC}"
            sleep 300
        done
        trap - SIGINT
    fi

    echo
    read -rp "${QUESTION} ¿Desea ver el Mapa de nodos? (s/n): " ver_mapa
    if [[ "$ver_mapa" =~ ^[sS]$ ]]; then
        generar_mapa
    else
        read -p "Presiona Enter para continuar..."
    fi
}

# ------------------------------------------------------------------
# Función para abrir archivos (compatible con Linux y macOS)
# ------------------------------------------------------------------
function open_file() {
    local file="$1"
    if command -v xdg-open &>/dev/null; then
        xdg-open "$file"
    elif command -v open &>/dev/null; then
        open "$file"
    else
        echo -e "${YELLOW}${INFO} Abre manualmente el archivo: $file${NC}"
    fi
}

# ------------------------------------------------------------------
# Verificar si ya existe un mapa y preguntar si se desea actualizar
# ------------------------------------------------------------------
function check_mapa_existente() {
    if [ -f "$MAP_FILE" ]; then
        echo -e "${YELLOW}${INFO} Ya existe un mapa creado en: ${MAP_FILE}${NC}"
        read -rp "${QUESTION} ¿Deseas actualizarlo? (s/n): " actualizar
        if [[ "$actualizar" =~ ^[sS]$ ]]; then
            echo -e "${CYAN}${INFO} Actualizando el mapa...${NC}"
            rm "$MAP_FILE"
        else
            echo -e "${GREEN}${SUCCESS} Mostrando el mapa existente...${NC}"
            open_file "$MAP_FILE"
            read -p "Presiona Enter para continuar..."
            return 1
        fi
    fi
    return 0
}

# ------------------------------------------------------------------
# Obtener información de Meshtastic
# ------------------------------------------------------------------
function obtener_informacion_meshtastic() {
    echo -e "${CYAN}${INFO} Obteniendo información de Meshtastic y generando mapa...${NC}"
    if [ -n "$MY_IP" ]; then     
        MESHTASTIC_OUTPUT="$(meshtastic --host "$MY_IP" --info 2>/dev/null)"
    else
        MESHTASTIC_OUTPUT="$(meshtastic --info 2>/dev/null)"   
    fi
    if [ -z "$MESHTASTIC_OUTPUT" ]; then
        echo -e "${RED}${WARN} No hay salida de 'meshtastic --info'.${NC}"
        read -p "Presiona Enter para continuar..."
        return 1
    fi
    return 0
}

# ------------------------------------------------------------------
# Extraer nodos y construir la variable NODES
# ------------------------------------------------------------------
function extraer_nodos() {
    MY_NODE_NUM=$(echo "$MESHTASTIC_OUTPUT" | grep -o '"myNodeNum": *[0-9]*' | head -n1 | sed 's/[^0-9]//g')

    IN_NODES=0
    IN_NODE=0
    DEPTH=0
    NAME=""
    LAT=""
    LON=""
    NUM=""
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

        if [ "$IN_NODE" -eq 0 ] && echo "$line" | grep -Eoq '^[[:space:]]*"[!][^"]+":[[:space:]]*\{'; then
            IN_NODE=1
            DEPTH=1
            NAME=""
            LAT=""
            LON=""
            NUM=""
            NODE_ID=$(echo "$line" | sed -n 's/^[[:space:]]*"\(![^"]*\)".*/\1/p')
            continue
        fi

        if [ "$IN_NODE" -eq 1 ]; then
            if echo "$line" | grep -q '"num":'; then
                extracted=$(echo "$line" | sed -n 's/.*"num": *\([0-9]*\).*/\1/p')
                [ -n "$extracted" ] && NUM="$extracted"
            fi

            opens=$(echo "$line" | sed 's/[^{}]//g' | tr -cd '{' | wc -c)
            closes=$(echo "$line" | sed 's/[^{}]//g' | tr -cd '}' | wc -c)
            DEPTH=$(( DEPTH + opens - closes ))

            if echo "$line" | grep -q '"shortName":'; then
                extracted=$(echo "$line" | sed -n 's/.*"shortName": *"\([^"]*\)".*/\1/p')
                [ -n "$extracted" ] && NAME="$extracted"
            fi

            if echo "$line" | grep -q '"latitude":'; then
                extracted=$(echo "$line" | sed -n 's/.*"latitude": *\([0-9.\-]*\).*/\1/p')
                [ -n "$extracted" ] && LAT="$extracted"
            fi

            if echo "$line" | grep -q '"longitude":'; then
                extracted=$(echo "$line" | sed -n 's/.*"longitude": *\([0-9.\-]*\).*/\1/p')
                [ -n "$extracted" ] && LON="$extracted"
            fi

            if [ "$DEPTH" -le 0 ]; then
                IN_NODE=0
                if { [ -z "$LAT" ] || [ -z "$LON" ]; } && [ "$NUM" = "$MY_NODE_NUM" ]; then
                    LAT="$MY_LAT"
                    LON="$MY_LON"
                fi
                if [ -n "$LAT" ] && [ -n "$LON" ]; then
                    [ -z "$NAME" ] && NAME="Nodo sin nombre"
                    NODES="$NODES
$NODE_ID	$NAME	$LAT	$LON"
                fi
            fi
        fi
    done <<< "$MESHTASTIC_OUTPUT"

    NODES=$(echo "$NODES" | sed '/^[[:space:]]*$/d')
    echo -e "${CYAN}${INFO} Nodos con coordenadas:${NC}"
    echo -e "${YELLOW}$NODES${NC}"

    if [ -z "$NODES" ]; then
        echo -e "${RED}${WARN} No se encontraron nodos con latitud/longitud.${NC}"
        read -p "Presiona Enter para continuar..."
        return 1
    fi
    return 0
}

# ------------------------------------------------------------------
# Gestionar el traceroute (actualizar o usar datos en caché)
# ------------------------------------------------------------------
function gestionar_traceroute() {
    echo ""
    ORIGEN="$1"
    if [ "$ORIGEN" == "auto" ]; then
        actualizar_traceroute="s"
    else
        read -rp "${QUESTION} ¿Deseas actualizar el traceroute para actualizar el mapa? (s/n): " actualizar_traceroute
    fi
    
    TRACEROUTE_COORDS=""
    TRACEROUTE_ROUTES=""

    if [[ "$actualizar_traceroute" =~ ^[sS]$ ]]; then
        if [ "$ORIGEN" == "auto" ]; then
            MAX_ATTEMPTS=10
        else
            read -rp "${QUESTION} Cuantos intentos quieres realizar por nodo? " MAX_ATTEMPTS
            if [[ -z "$MAX_ATTEMPTS" || ! "$MAX_ATTEMPTS" =~ ^[0-9]+$ ]]; then
                MAX_ATTEMPTS=1
            fi
        fi
    
        echo -e "${CYAN}${INFO} Ejecutando traceroute en los nodos...${NC}"

        cancel_traceroute=0
        trap 'echo -e "\n${RED}${WARN} Traceroute detenido por el usuario. Presiona Enter para continuar...${NC}"; read -p ""; cancel_traceroute=1' SIGINT

        nodes_list=""
        while IFS=$'\t' read -r node_id node_name node_lat node_lon; do
            nodes_list="${nodes_list}${node_id},${node_lat},${node_lon},1\n"
        done <<< "$NODES"

        declare -A coords
        while IFS=',' read -r id lat lon hops; do
            [ -z "$id" ] && continue
            coords["$id"]="${lat},${lon}"
        done < <(echo -e "$nodes_list" | sed '/^\s*$/d')

        successful_routes=""
        while IFS=',' read -r id lat lon hops; do
            [ -z "$id" ] && continue
            if [ "$cancel_traceroute" -eq 1 ]; then
                break
            fi
            echo ""
            echo -e "${MAG}${INFO} Realizando traceroute a ${YELLOW}$id${NC}..."
            attempt=1
            route_found=""
            while [ $attempt -le $MAX_ATTEMPTS ]; do
                if [ "$cancel_traceroute" -eq 1 ]; then
                    break 2
                fi
                echo -e "${CYAN}${INFO} Intento ${YELLOW}$attempt${NC} de ${YELLOW}$MAX_ATTEMPTS${NC} para ${YELLOW}$id${NC}..."
                if [ -n "$MY_IP" ]; then
                    echo -e "${BLUE}${INFO} Enviando requerimiento de telemetría y posición...${NC}"
                    meshtastic --host "$MY_IP" --request-position --request-telemetry --dest "$id"
                    echo -e "${BLUE}${INFO} Realizando TRACEROUTE...${NC}"
                    output=$(meshtastic --host "$MY_IP" --traceroute "$id" 2>&1)
                else
                    echo -e "${BLUE}${INFO} Enviando requerimiento de telemetría y posición...${NC}"
                    meshtastic --request-position --request-telemetry --dest "$id"
                    echo -e "${BLUE}${INFO} Realizando TRACEROUTE...${NC}"
                    output=$(meshtastic --traceroute "$id" 2>&1)
                fi
                route_line=$(echo "$output" | awk '/Route traced:/{getline; print}')
                if [ -n "$route_line" ]; then
                    route_found=$(echo "$route_line" | xargs)
                    break
                else
                    echo -e "${RED}${WARN} Sin respuesta en intento ${YELLOW}$attempt${NC} para ${YELLOW}$id${NC}."
                fi
                attempt=$((attempt+1))
            done

            if [ "$cancel_traceroute" -eq 1 ]; then
                break
            fi

            if [ -n "$route_found" ]; then
                echo -e "${GREEN}${SUCCESS} Traceroute a ${YELLOW}$id${NC} respondido: ${CYAN}$route_found${NC}"
                route_ids=$(echo "$route_found" | sed 's/ *--> */,/g')
                IFS=',' read -ra arr <<< "$route_ids"
                route_json=""
                first=1
                for element in "${arr[@]}"; do
                    element=$(echo "$element" | xargs)
                    if [ $first -eq 1 ]; then
                        route_json="\"$element\""
                        first=0
                    else
                        route_json="$route_json, \"$element\""
                    fi
                done
                route_json="[$route_json]"
                route_object=$(printf '{"id": "%s", "route": %s}' "$id" "$route_json")
                successful_routes="${successful_routes}${route_object},\n"
            else
                echo -e "${RED}${WARN} No se obtuvo respuesta de ${YELLOW}$id${NC} tras intentar ${YELLOW}$MAX_ATTEMPTS${NC} Traceroute."
            fi
        done < <(echo -e "$nodes_list" | sed '/^\s*$/d')

        trap - SIGINT

        if [ "$cancel_traceroute" -eq 1 ]; then
            echo ""
            echo -e "${RED}${WARN} Mapa Traceroute cancelado...${NC}"
            read -p "Pulse Enter para continuar..."
            return 1
        fi

        successful_routes=$(echo -e "$successful_routes" | sed '/^\s*$/d')
        if [ -z "$successful_routes" ]; then
            echo -e "${RED}${WARN} Ningún nodo respondió al traceroute.${NC}"
        fi

        coords_json="{"
        for key in "${!coords[@]}"; do
            value=${coords[$key]}
            lat_val=$(echo "$value" | cut -d, -f1)
            lon_val=$(echo "$value" | cut -d, -f2)
            coords_json="$coords_json \"$key\": [$lat_val, $lon_val],"
        done
        coords_json="$coords_json \"OWNER\": [$MY_LAT, $MY_LON]"
        coords_json="${coords_json%,} }"
        TRACEROUTE_COORDS="$coords_json"
        TRACEROUTE_ROUTES=$(echo -e "$successful_routes" | sed '$ s/,$//')

        echo "$TRACEROUTE_COORDS" > "$TRACEROUTE_COORDS_CACHE"
        echo "$TRACEROUTE_ROUTES" > "$TRACEROUTE_ROUTES_CACHE"
    else
        if [ -f "$TRACEROUTE_COORDS_CACHE" ] && [ -f "$TRACEROUTE_ROUTES_CACHE" ]; then
            echo -e "${GREEN}${INFO} Usando datos de traceroute en caché.${NC}"
            TRACEROUTE_COORDS=$(cat "$TRACEROUTE_COORDS_CACHE")
            TRACEROUTE_ROUTES=$(cat "$TRACEROUTE_ROUTES_CACHE")
        else
            echo -e "${RED}${WARN} No hay datos de traceroute en caché.${NC}"
            TRACEROUTE_COORDS=""
            TRACEROUTE_ROUTES=""
        fi
    fi
    return 0
}

# ------------------------------------------------------------------
# Generar el HTML del mapa a partir de los nodos y rutas
# ------------------------------------------------------------------
function crear_html_mapa() {
    ORIGEN="$1"
    FIRST_LINE="$(echo "$NODES" | head -n1)"
    FIRST_NODE_ID=$(echo "$FIRST_LINE" | cut -f1)
    FIRST_NAME=$(echo "$FIRST_LINE" | cut -f2)
    FIRST_LAT=$(echo "$FIRST_LINE" | cut -f3)
    FIRST_LON=$(echo "$FIRST_LINE" | cut -f4)

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

    echo "$NODES" | while IFS=$'\t' read -r node_id node_name node_lat node_lon; do
        SAFE_NAME=$(echo "$node_name" | sed "s/'/\\'/g")
        cat <<EOF >> "$MAP_FILE"
L.marker([$node_lat, $node_lon]).addTo(map)
  .bindPopup('<div class="popup-text"><b>$SAFE_NAME</b><br>Lat: $node_lat<br>Lon: $node_lon</div>');
EOF
    done

    if [ -n "$TRACEROUTE_COORDS" ] && [ -n "$TRACEROUTE_ROUTES" ]; then
        cat <<EOF >> "$MAP_FILE"

 // Mapeo de coordenadas por node id (para traceroute)
var coords = $TRACEROUTE_COORDS;

// Array de rutas exitosas (traceroute)
var routes = [
$TRACEROUTE_ROUTES
];

// Dibujar las rutas en el mapa
routes.forEach(function(r) {
  var route_coords = [];
  r.route.forEach(function(nid) {
    if (coords.hasOwnProperty(nid)) {
      route_coords.push(coords[nid]);
    } else {
      route_coords.push(coords["OWNER"]);
    }
  });
  L.polyline(route_coords, {color: 'blue', weight: 3, opacity: 0.8}).addTo(map)
    .bindPopup("Traceroute: " + r.route.join(" --> "));
});
EOF
    fi

    cat <<EOF >> "$MAP_FILE"
</script>
</body>
</html>
EOF

    echo -e "${GREEN}${SUCCESS} Mapa generado en: ${YELLOW}$MAP_FILE${NC}"
    open_file "$MAP_FILE"
    ORIGEN="$1"
    if [ "$ORIGEN" != "auto" ]; then
        read -p "Presiona Enter para continuar..."
    fi
    return 0
}

# ------------------------------------------------------------------
# Función principal: genera el mapa llamando a las funciones anteriores
# ------------------------------------------------------------------
function generar_mapa() {
    ORIGEN="$1"
    if [ "$ORIGEN" == "auto" ]; then
        echo -e "${INFO} Presiona CTRL+C para detener la actualización y regresar al menú principal.${NC}"
        trap 'echo ""; echo -e "${RED}${WARN} Bucle interrumpido. Regresando al menú...${NC}"; break' SIGINT
        while true; do
            obtener_informacion_meshtastic || return
            extraer_nodos || return
            gestionar_traceroute auto || return
            crear_html_mapa auto
        done
        trap - SIGINT
    else
        check_mapa_existente || return
        obtener_informacion_meshtastic || return
        extraer_nodos || return
        gestionar_traceroute || return
        crear_html_mapa
    fi
}

# ------------------------------------------------------------------
# Bucle principal
# ------------------------------------------------------------------
while true; do
    mostrar_menu
    read -rp "${QUESTION} Selecciona una opción: " opcion
    case $opcion in
        0)
            auto
            ;;
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
            configuracion
            ;;
        6)
            echo -e "${GREEN}${SUCCESS} Saliendo del script.${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}${WARN} Opción no válida. Inténtalo de nuevo.${NC}"
            read -p "Presiona Enter para continuar..."
            ;;
    esac
done
