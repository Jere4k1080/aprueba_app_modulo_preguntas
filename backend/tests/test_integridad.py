"""Regla 1 de CLAUDE.md y RNF-02: ninguna ruta entrega correctAnswer ni explanation, en ningún nivel del JSON,
antes de responder.

Recorre todas las rutas registradas, así que una ruta nueva entra sola en la prueba. POST
/questions/{id}/answer, de la iteración 4, será la única que devuelva correctAnswer, después de responder, y
tendrá que quedar como excepción explícita."""

BEARER = {"Authorization": "Bearer token.de.firebase"}
PROHIBIDAS = {"correctAnswer", "explanation"}
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


def test_ninguna_ruta_entrega_la_respuesta_ni_la_explicacion(banco):
    vistas = rutas(banco.app)
    esperadas = {("GET", "/api/v1/health"), ("GET", "/api/v1/me"), ("GET", "/api/v1/tests"),
                 ("GET", "/api/v1/me/preferences"), ("PUT", "/api/v1/me/preferences"), ("GET", "/api/v1/practice/next"),
                 ("GET", "/api/v1/questions/{question_id}")}
    assert esperadas <= set(vistas), f"faltan rutas en el recorrido: {esperadas - set(vistas)}"
    # El parámetro de las rutas de pregunta es la pendiente del alumno, la única que puede pedir por ID (ADR-85).
    pendiente = banco.cliente.get("/api/v1/practice/next", headers=BEARER).json()["data"]["id"]
    estados = {}
    for metodo, ruta in vistas:
        url = ruta.replace("{question_id}", pendiente)
        assert "{" not in url, f"{ruta}: agrega aquí un valor de prueba para su parámetro"
        cuerpo = CUERPOS.get((metodo, ruta), {}) if metodo in ("POST", "PUT", "PATCH") else None
        res = banco.cliente.request(metodo, url, headers=BEARER, json=cuerpo)
        estados[(metodo, ruta)] = res.status_code
        if "json" in res.headers.get("content-type", ""):
            entregadas = PROHIBIDAS & set(claves(res.json()))
            assert not entregadas, f"{metodo} {ruta} entrega {entregadas}"
    # Si la pregunta no llegara, la prueba no estaría revisando las respuestas que importan.
    assert estados[("GET", "/api/v1/practice/next")] == 200
    assert estados[("GET", "/api/v1/questions/{question_id}")] == 200
    assert estados[("PUT", "/api/v1/me/preferences")] == 200
