"""Emulador de Firestore de las pruebas. Se reconoce por lo que responde y no solo por el puerto."""
import functools
import http.client
import urllib.request

HOST = "127.0.0.1:8080"

# Sin proxy: el emulador es local aunque el entorno defina HTTP_PROXY.
_abrir = urllib.request.build_opener(urllib.request.ProxyHandler({})).open


@functools.cache
def activo() -> bool:
    """True si en HOST está el emulador de Firestore, que responde 200 y "Ok" en la raíz. Otro programa en
    el mismo puerto no cuenta: con él las pruebas creerían tener el emulador y fallarían. Se consulta una vez
    por corrida, porque en Windows un puerto cerrado tarda el segundo completo de espera."""
    try:
        with _abrir(f"http://{HOST}/", timeout=1) as respuesta:
            return respuesta.status == 200 and respuesta.read(16).strip() == b"Ok"
    except (OSError, http.client.HTTPException):
        return False


def vaciar(proyecto: str) -> None:
    """Borra todos los documentos de un proyecto del emulador."""
    pedido = urllib.request.Request(
        f"http://{HOST}/emulator/v1/projects/{proyecto}/databases/(default)/documents", method="DELETE")
    _abrir(pedido, timeout=10).close()
