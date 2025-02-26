import curses
import threading
import time
import string
import json
import meshtastic
from meshtastic import serial_interface
from pubsub import pub
from tabulate import tabulate

# Variables globales para la UI
messages_table = []    # Lista de dicts: {"From": ..., "Port": ..., "Payload": ...}
traceroutes_table = [] # Lista de dicts: {"NodeID": ..., "Route": ...}
global_mesh = None     # Referencia a la instancia de MeshInterface

def sanitize_text(text):
    """Devuelve solo caracteres imprimibles, reemplazando lo demás por '?'."""
    return ''.join(ch if ch in string.printable else '?' for ch in text)

def safe_convert(value):
    """
    Intenta convertir 'value' a una cadena JSON; si falla, devuelve str(value).
    Así evitamos errores de "not JSON serializable".
    """
    try:
        if isinstance(value, bytes):
            return value.decode("utf-8", errors="replace")
        return json.dumps(value, indent=1)
    except Exception:
        return str(value)

def on_receive(packet, interface=None):
    """
    Callback para capturar mensajes y guardarlos en messages_table, formateando
    la información según el tipo de mensaje. Además, si el mensaje es TRACEROUTE_APP
    y contiene una ruta, se actualiza traceroutes_table.
    """
    try:
        frm = packet.get("fromId", str(packet.get("from")))
        decoded = packet.get("decoded", {})
        port = decoded.get("portnum", "N/A")
        if port == "TRACEROUTE_APP":
            traceroute_info = decoded.get("traceroute", {})
            route = traceroute_info.get("route")
            if route:
                payload_str = "Route: " + safe_convert(route)
                # Actualiza traceroutes_table
                global traceroutes_table
                traceroutes_table.append({"NodeID": frm, "Route": safe_convert(route)})
                if len(traceroutes_table) > 10:
                    traceroutes_table.pop(0)
            else:
                payload_str = "No route info"
        elif port == "TELEMETRY_APP":
            telemetry_info = decoded.get("telemetry", {})
            payload_str = "Telemetry: " + safe_convert(telemetry_info)
        elif port == "NODEINFO_APP":
            user_info = decoded.get("user", {})
            payload_str = "User: " + safe_convert(user_info)
        elif port == "TEXT_MESSAGE_APP":
            payload = decoded.get("payload", b"")
            payload_str = safe_convert(payload)
        else:
            payload_str = safe_convert(decoded)
        payload_str = sanitize_text(payload_str)
        entry = {"From": frm, "Port": port, "Payload": payload_str}
        messages_table.append(entry)
        if len(messages_table) > 50:
            messages_table.pop(0)
    except Exception as e:
        messages_table.append({"From": "Error", "Port": "N/A", "Payload": str(e)})

pub.subscribe(on_receive, "meshtastic.receive")

def send_messages(mesh):
    """Permite enviar mensajes desde la terminal (entrada estándar)."""
    while True:
        user_input = input("Escribe tu mensaje (usar 'user:<ID> <mensaje>' para usuario específico): ")
        try:
            if user_input.startswith("user:"):
                parts = user_input.split(" ", 1)
                target_str = parts[0]
                msg_text = parts[1]
                target_id = target_str.split(":", 1)[1]
                mesh.sendText(msg_text, destinationId=target_id)
            else:
                mesh.sendText(user_input)
        except Exception as e:
            print("Error enviando mensaje:", e)

def real_traceroute(mesh, node_id, hop_limit=10, wait_factor=1):
    """
    Envía una solicitud real de traceroute al nodo indicado usando sendTraceRoute
    y espera la respuesta con waitForTraceRoute.
    Se asume que la respuesta incluye en decoded.traceroute.route una lista de hops.
    """
    try:
        mesh.sendTraceRoute(node_id, hop_limit)
        print(f"Solicitud de traceroute enviada a {node_id}.")
        response = mesh.waitForTraceRoute(wait_factor)
        if response:
            route = response.get("decoded", {}).get("traceroute", {}).get("route", [])
            if route:
                return route
        return None
    except Exception as e:
        print("Error en traceroute:", e)
        return None

def scheduler_traceroute(mesh):
    """
    Recorre los nodos que tienen datos de posición y para cada uno envía una
    solicitud de traceroute real. Si se recibe una ruta, se guarda en traceroutes_table.
    """
    global traceroutes_table
    while True:
        localizable_nodes = {
            node_id: node
            for node_id, node in mesh.nodes.items()
            if node.get("position") and node["position"].get("latitude") is not None and node["position"].get("longitude") is not None
        }
        if localizable_nodes:
            for node_id, node in localizable_nodes.items():
                print(f"Iniciando traceroute real para el nodo {node_id}...")
                route = real_traceroute(mesh, node_id)
                if route:
                    route_str = " --> ".join(str(hop) for hop in route)
                    traceroutes_table.append({"NodeID": node_id, "Route": route_str})
                    if len(traceroutes_table) > 10:
                        traceroutes_table.pop(0)
        else:
            print("No hay nodos localizables. Esperando para reintentar traceroute...")
        time.sleep(600)

def curses_ui(stdscr):
    """Interfaz de usuario en curses que muestra tres áreas: mensajes, nodos y traceroutes."""
    curses.curs_set(0)
    stdscr.nodelay(True)
    max_y, max_x = stdscr.getmaxyx()
    
    # Dividir la pantalla verticalmente en 3 áreas
    height_msgs = max_y // 3
    height_nodes = max_y // 3
    height_traceroutes = max_y - height_msgs - height_nodes

    win_msgs = curses.newwin(height_msgs, max_x, 0, 0)
    win_nodes = curses.newwin(height_nodes, max_x, height_msgs, 0)
    win_traceroutes = curses.newwin(height_traceroutes, max_x, height_msgs + height_nodes, 0)

    while True:
        win_msgs.clear()
        win_nodes.clear()
        win_traceroutes.clear()
        
        # Área de mensajes recibidos
        win_msgs.addstr(0, 0, "Mensajes recibidos:")
        try:
            if messages_table:
                table_str = tabulate(messages_table, headers="keys", tablefmt="plain")
                lines = table_str.splitlines()
            else:
                lines = ["Sin mensajes"]
        except Exception as e:
            lines = [str(e)]
        for i, line in enumerate(lines[:height_msgs - 1]):
            try:
                win_msgs.addstr(i + 1, 0, line[:max_x - 1])
            except curses.error:
                pass

        # Área de nodos conectados
        win_nodes.addstr(0, 0, "Nodos conectados:")
        nodes_table = []
        if global_mesh:
            for node_id, node in global_mesh.nodes.items():
                pos = node.get("position", {})
                lat = pos.get("latitude", "N/A")
                lon = pos.get("longitude", "N/A")
                user = node.get("user", {})
                username = user.get("name", "N/A")
                nodes_table.append([node_id, username, lat, lon])
        try:
            table_str = tabulate(nodes_table, headers=["NodeID", "User", "Lat", "Lon"], tablefmt="plain")
            lines = table_str.splitlines()
        except Exception as e:
            lines = [str(e)]
        for i, line in enumerate(lines[:height_nodes - 1]):
            try:
                win_nodes.addstr(i + 1, 0, line[:max_x - 1])
            except curses.error:
                pass

        # Área de traceroutes
        win_traceroutes.addstr(0, 0, "Traceroutes:")
        try:
            if traceroutes_table:
                table_str = tabulate(traceroutes_table, headers="keys", tablefmt="plain")
                lines = table_str.splitlines()
            else:
                lines = ["Sin traceroutes"]
        except Exception as e:
            lines = [str(e)]
        for i, line in enumerate(lines[:height_traceroutes - 1]):
            try:
                win_traceroutes.addstr(i + 1, 0, line[:max_x - 1])
            except curses.error:
                pass

        stdscr.refresh()
        win_msgs.refresh()
        win_nodes.refresh()
        win_traceroutes.refresh()
        time.sleep(1)

def main():
    global global_mesh
    mesh = serial_interface.SerialInterface()
    global_mesh = mesh
    print("Conectado a Meshtastic.")

    thread_msgs = threading.Thread(target=send_messages, args=(mesh,), daemon=True)
    thread_traceroute = threading.Thread(target=scheduler_traceroute, args=(mesh,), daemon=True)
    thread_msgs.start()
    thread_traceroute.start()

    curses.wrapper(curses_ui)

if __name__ == "__main__":
    main()
