"""GET /tests, GET y PUT /me/preferences y GET /practice/next contra el emulador (ADR-72 y ADR-73)."""
import asyncio

from google.cloud import firestore

from app import seed
from app.services.practice import pick_question
from app.services.users import quota_day

BEARER = {"Authorization": "Bearer token.de.firebase"}
PREFS = "/api/v1/me/preferences"
NEXT = "/api/v1/practice/next"
RESPONDIDAS = {a["questionId"] for a in seed.load("answers")["demo"]}


def put(banco, **cambios):
    body = {"selectedTests": ["lectora", "m1"], "format": "random", "difficulty": "d1", **cambios}
    return banco.cliente.put(PREFS, headers=BEARER, json=body)


def test_catalogo_de_pruebas_con_has_questions(banco):
    banco.db.document("tests/hist").update({"approvedStock": 0})
    banco.db.document("tests/extra").set({"label": "Inactiva", "color": "#000000", "order": 9, "active": False,
                                           "approvedStock": 3})
    data = banco.cliente.get("/api/v1/tests", headers=BEARER).json()["data"]
    assert [t["id"] for t in data] == ["lectora", "m1", "m2", "cien", "hist"], "solo activas y en su orden"
    assert [t["hasQuestions"] for t in data] == [True, True, True, True, False], "hasQuestions es approvedStock > 0"
    assert data[0] == {"id": "lectora", "label": "Comp. Lectora", "color": "#1A365D", "hasQuestions": True}


def test_preferencias_get_y_put(banco):
    antes = banco.cliente.get(PREFS, headers=BEARER).json()["data"]
    assert antes == {"selectedTests": ["lectora", "m1", "m2", "cien", "hist"], "format": "random", "difficulty": "d1",
                     "country": "CL", "language": "es", "gradeId": None, "onboarded": True}
    res = put(banco, selectedTests=["m1", "lectora", "m1"], difficulty="d2", country="UK", language="en", gradeId="4m")
    assert res.status_code == 200, res.text
    assert res.json()["data"] == {"selectedTests": ["m1", "lectora"], "format": "random", "difficulty": "d2",
                                  "country": "UK", "language": "en", "gradeId": "4m", "onboarded": True}
    doc = banco.user.get().to_dict()
    assert (doc["selectedTests"], doc["practiceFormat"], doc["difficulty"], doc["locale"], doc["gradeId"]) == \
        (["m1", "lectora"], "random", "d2", "en", "4m")


def test_put_rechaza_seleccion_vacia_o_pruebas_sin_preguntas(banco):
    vacia = put(banco, selectedTests=[])
    assert vacia.status_code == 400
    assert (vacia.json()["error"]["code"], vacia.json()["error"]["field"]) == ("NO_TESTS_SELECTED", "selectedTests")
    assert vacia.json()["error"]["message"] == "Debe seleccionarse al menos una prueba.", "el texto del contrato"
    en = banco.cliente.put(PREFS, headers={**BEARER, "Accept-Language": "en"},
                           json={"selectedTests": [], "format": "random", "difficulty": "d1"})
    assert en.json()["error"]["message"] == "At least one test must be selected."
    sin_campo = banco.cliente.put(PREFS, headers=BEARER, json={"format": "random", "difficulty": "d1"})
    assert (sin_campo.status_code, sin_campo.json()["error"]["code"]) == (400, "VALIDATION_ERROR"), "falta el campo"
    banco.db.document("tests/hist").update({"approvedStock": 0})
    mala = put(banco, selectedTests=["lectora", "hist", "maths"])
    error = mala.json()["error"]
    assert mala.status_code == 400 and (error["code"], error["field"]) == ("VALIDATION_ERROR", "selectedTests")
    assert [d["message"] for d in error["details"]] == ["The test hist has no questions.", "The test maths has no questions."]
    assert banco.user.get().to_dict()["selectedTests"] == ["lectora", "m1", "m2", "cien", "hist"], "no guarda nada"


def test_put_formato_facsimil_segun_el_plan_y_dificultad(banco):
    facsim = put(banco, format="facsim")
    assert facsim.status_code == 422
    assert (facsim.json()["error"]["code"], facsim.json()["error"]["field"]) == ("FORMAT_REQUIRES_PLAN", "format")
    banco.user.update({"plan": "all"})  # all incluye f2, mock_mode (ADR-70)
    assert put(banco, format="facsim").status_code == 200
    dificultad = put(banco, difficulty="d5")
    assert dificultad.status_code == 400 and dificultad.json()["error"]["field"] == "difficulty"


def test_practice_next_entrega_una_pregunta_sin_la_respuesta(banco):
    res = banco.cliente.get(NEXT, headers=BEARER)
    assert res.status_code == 200, res.text
    pregunta, meta = res.json()["data"], res.json()["meta"]
    assert "correctAnswer" not in res.text and "explanation" not in pregunta
    assert set(pregunta) == {"id", "testId", "axis", "skillId", "difficulty", "statement", "options", "progress"}
    assert pregunta["id"] not in RESPONDIDAS and pregunta["difficulty"] == "d1"
    assert pregunta["progress"] == {"current": 6, "total": 10}, "progress sale de la cuota del día"
    assert meta["quota"] == {"used": 5, "max": 10, "unlimited": False}
    assert banco.user.get().to_dict()["quota"]["used"] == 5, "no descuenta: eso lo hace la respuesta (ADR-72)"


def test_la_pendiente_se_repite_sin_gastar_cuota(banco):
    primera = banco.cliente.get(NEXT, headers=BEARER).json()
    segunda = banco.cliente.get(NEXT, headers=BEARER).json()
    assert segunda["data"] == primera["data"], "dos pedidos seguidos sin responder dan la misma pregunta"
    assert segunda["meta"]["quota"] == primera["meta"]["quota"] and banco.user.get().to_dict()["quota"]["used"] == 5
    assert banco.estado.get().to_dict()["lastQuestionId"] == primera["data"]["id"]
    # La transacción de responder (iteración 4) la agrega a answeredQuestionIds y deja de estar pendiente.
    banco.estado.update({"answeredQuestionIds": firestore.ArrayUnion([primera["data"]["id"]])})
    tercera = banco.cliente.get(NEXT, headers=BEARER).json()["data"]
    assert tercera["id"] != primera["data"]["id"]


def test_una_pendiente_que_dejo_de_estar_publicada_se_reemplaza(banco):
    primera = banco.cliente.get(NEXT, headers=BEARER).json()["data"]
    banco.db.document(f"questions/{primera['id']}").update({"status": "retired"})
    assert banco.cliente.get(NEXT, headers=BEARER).json()["data"]["id"] != primera["id"]


def test_reinicio_de_la_cuota_al_cambiar_el_dia(banco):
    banco.user.update({"quota.date": "2020-01-01", "quota.used": 10, "quota.max": 15})
    res = banco.cliente.get(NEXT, headers=BEARER)
    assert res.status_code == 200 and res.json()["meta"]["quota"] == {"used": 0, "max": 10, "unlimited": False}
    assert banco.user.get().to_dict()["quota"] == {"used": 0, "max": 10, "date": quota_day(), "unlimited": False,
                                                   "bonusSchool": False, "bonusAddress": False}


def test_cuota_base_alcanzada_y_limite_diario(banco):
    banco.user.update({"quota.used": 10})
    base = banco.cliente.get(NEXT, headers=BEARER)
    assert base.status_code == 422 and base.json()["error"]["code"] == "QUOTA_BASE_REACHED"
    banco.user.update({"quota.used": 20, "quota.max": 20, "quota.bonusSchool": True, "quota.bonusAddress": True})
    tope = banco.cliente.get(NEXT, headers=BEARER)
    assert tope.status_code == 422 and tope.json()["error"]["code"] == "QUOTA_DAILY_LIMIT"
    # Con qDay 20 el máximo ya está en el tope y los bonos no suman: no se ofrece el desbloqueo.
    banco.user.update({"quota.bonusSchool": False, "quota.bonusAddress": False})
    assert banco.cliente.get(NEXT, headers=BEARER).json()["error"]["code"] == "QUOTA_DAILY_LIMIT"


def test_plan_ilimitado_sin_tope(banco):
    banco.user.update({"plan": "all", "quota.used": 50, "quota.max": 0, "quota.unlimited": True})
    res = banco.cliente.get(NEXT, headers=BEARER)
    assert res.status_code == 200 and res.json()["meta"]["quota"] == {"used": 50, "max": 0, "unlimited": True}
    assert res.json()["data"]["progress"] == {"current": 51, "total": None}


def test_sin_pruebas_elegidas_o_sin_preguntas_por_responder(banco):
    banco.user.update({"selectedTests": []})
    sin_pruebas = banco.cliente.get(NEXT, headers=BEARER).json()["error"]
    assert (sin_pruebas["code"], sin_pruebas["field"], sin_pruebas["details"][0]["type"]) == \
        ("NO_QUESTIONS_AVAILABLE", "selectedTests", "NO_TESTS_SELECTED")
    # La única pregunta d2 de lectora ya está respondida.
    banco.user.update({"selectedTests": ["lectora"], "difficulty": "d2"})
    res = banco.cliente.get(NEXT, headers=BEARER)
    assert res.status_code == 404 and (res.json()["error"]["code"], res.json()["error"]["field"]) == \
        ("NO_QUESTIONS_AVAILABLE", None)


def test_pick_question_da_la_vuelta_desde_cero(banco):
    async def elegir():
        db = firestore.AsyncClient(project=banco.db.project)
        # Con r casi 1 el primer tramo queda vacío y la búsqueda sigue desde randomKey 0.
        return await pick_question(db, ["m2", "cien"], "d1", set(), r=0.9999999)

    assert asyncio.run(elegir())["id"] in {q["id"] for q in seed.load("questions")
                                           if q["testId"] in ("m2", "cien") and q["difficulty"] == "d1"}
