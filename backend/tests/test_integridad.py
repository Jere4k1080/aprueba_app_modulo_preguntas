"""Regla 1 de CLAUDE.md: ninguna ruta entrega correctAnswer, en ningún nivel del JSON, antes de responder.

Recorre todas las rutas registradas, así que una ruta nueva entra sola en la prueba. POST
/questions/{id}/answer, de la iteración 5, será la única que la devuelva, después de responder, y tendrá
que quedar como excepción explícita."""

BEARER = {"Authorization": "Bearer token.de.firebase"}
# Cuerpos válidos para las rutas que los piden; las demás reciben {}.
CUERPOS = {("PUT", "/api/v1/me/preferences"): {"selectedTests": ["m2"], "format": "random", "difficulty": "d1"}}


def rutas(app) -> list[tuple[str, str]]:
    def recorrer(routes, prefijo=""):
        for r in routes:
            if hasattr(r, "original_router"):  # FastAPI 0.141 deja cada router incluido como _IncludedRouter
                yield from recorrer(r.original_router.routes, prefijo + r.include_context.prefix)
            elif getattr(r, "methods", None):
                yield from ((m, prefijo + r.path) for m in r.methods if m not in ("HEAD", "OPTIONS"))
    # Primero los GET, para que la pregunta se pida con las preferencias del seed.
    return sorted(set(recorrer(app.routes)), key=lambda mr: (mr[0] != "GET", mr[1]))


def claves(x):
    if isinstance(x, dict):
        for k, v in x.items():
            yield k
            yield from claves(v)
    elif isinstance(x, list):
        for v in x:
            yield from claves(v)


def test_ninguna_ruta_entrega_correct_answer(banco):
    vistas = rutas(banco.app)
    esperadas = {("GET", "/api/v1/health"), ("GET", "/api/v1/me"), ("GET", "/api/v1/tests"),
                 ("GET", "/api/v1/me/preferences"), ("PUT", "/api/v1/me/preferences"), ("GET", "/api/v1/practice/next")}
    assert esperadas <= set(vistas), f"faltan rutas en el recorrido: {esperadas - set(vistas)}"
    estados = {}
    for metodo, ruta in vistas:
        assert "{" not in ruta, f"{ruta}: agrega aquí un valor de prueba para su parámetro"
        cuerpo = CUERPOS.get((metodo, ruta), {}) if metodo in ("POST", "PUT", "PATCH") else None
        res = banco.cliente.request(metodo, ruta, headers=BEARER, json=cuerpo)
        estados[(metodo, ruta)] = res.status_code
        if "json" in res.headers.get("content-type", ""):
            assert "correctAnswer" not in set(claves(res.json())), f"{metodo} {ruta} entrega correctAnswer"
    # Si la pregunta no llegara, la prueba no estaría revisando la respuesta que importa.
    assert estados[("GET", "/api/v1/practice/next")] == 200
    assert estados[("PUT", "/api/v1/me/preferences")] == 200
