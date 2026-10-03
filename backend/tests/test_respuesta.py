"""POST /questions/{id}/answer contra el emulador (HU-03, T-28, T-29, HT-04 y T-30; ADR-86 y ADR-87)."""
import asyncio
from datetime import datetime, timedelta, timezone

from google.api_core import exceptions
from google.cloud import firestore
from google.cloud.firestore_v1.async_transaction import AsyncTransaction

from app import seed
from app.core.errors import ApiError
from app.services import answers
from app.services.answers import register_answer
from app.services.users import quota_day

BEARER = {"Authorization": "Bearer token.de.firebase"}
NEXT = "/api/v1/practice/next"
PREGUNTAS = {q["id"]: q for q in seed.load("questions")}
CINCO = "qst_a998954ca4"       # m1 d1, cinco alternativas, correcta B; su habilidad tiene una respuesta en el seed
CUATRO = "qst_d156e63a9d"      # m1 d1, cuatro alternativas, correcta A; su habilidad no tiene respuestas
RESPONDIDA = "qst_9873643c47"  # respondida en el seed


def pendiente(banco, question_id, segundos=30):
    """Deja question_id como pendiente, entregada por la API hace `segundos`."""
    banco.estado.update({"lastQuestionId": question_id,
                         "deliveredAt": datetime.now(timezone.utc) - timedelta(seconds=segundos)})


def responder(banco, question_id, selected, **extra):
    return banco.cliente.post(f"/api/v1/questions/{question_id}/answer", headers=BEARER,
                              json={"selected": selected, **extra})


def error(res):
    return res.status_code, res.json()["error"]["code"]


def respuesta(banco, question_id):
    return banco.user.collection("answers").document(question_id).get()


def medallas(banco, question_id):
    return [d.to_dict() for d in banco.db.collection("medalTransactions").stream()
            if d.get("refId") == question_id and d.get("userId") == banco.user.id]


def test_correcta_descuenta_cuota_y_da_las_medallas_del_plan(banco):
    antes = banco.user.get().to_dict()
    pendiente(banco, CINCO)
    res = responder(banco, CINCO, "B")
    assert res.status_code == 200, res.text
    assert res.json()["data"] == {
        "correct": True, "correctAnswer": "B",
        "shortExplanation": PREGUNTAS[CINCO]["explanation"].splitlines()[0].removeprefix("1. "),
        "cohortPercentile": None, "medalAwarded": {"tier": "bronze", "amount": 1},
        "quota": {"used": 6, "max": 10, "unlimited": False},
    }
    despues = banco.user.get().to_dict()
    assert despues["quota"]["used"] == antes["quota"]["used"] + 1 == 6
    assert despues["medalWallet"]["bronze"] == antes["medalWallet"]["bronze"] + 1, "badges.correct de free"
    assert despues["badgesTotal"] == antes["badgesTotal"] + 1
    [mtx] = medallas(banco, CINCO)
    assert mtx["at"] and {**mtx, "at": None} == {"userId": banco.user.id, "tier": "bronze", "amount": 1,
                                                 "reason": "answer_correct", "refId": CINCO, "at": None}
    doc = respuesta(banco, CINCO).to_dict()
    assert {k: doc[k] for k in ("questionId", "testId", "axis", "skillId", "selected", "correct", "difficulty")} == \
        {"questionId": CINCO, "testId": "m1", "axis": "Números", "skillId": "sk_demo_m1_operatoria", "selected": "B",
         "correct": True, "difficulty": "d1"}, "el ID del documento es el de la pregunta"
    estado = banco.estado.get().to_dict()
    assert CINCO in estado["answeredQuestionIds"] and "lastQuestionId" not in estado and "deliveredAt" not in estado


def test_plan_ilimitado_sin_tope_y_con_sus_medallas(banco):
    banco.user.update({"plan": "all", "quota.used": 50, "quota.max": 0, "quota.unlimited": True})
    pendiente(banco, CINCO)
    data = responder(banco, CINCO, "B").json()["data"]
    assert data["medalAwarded"] == {"tier": "bronze", "amount": 2}, "badges.correct de all"
    assert data["quota"] == {"used": 51, "max": 0, "unlimited": True}
    assert medallas(banco, CINCO)[0]["amount"] == 2


def test_incorrecta_descuenta_cuota_sin_medallas(banco):
    antes = banco.user.get().to_dict()
    pendiente(banco, CINCO)
    data = responder(banco, CINCO, "D").json()["data"]
    assert (data["correct"], data["correctAnswer"], data["medalAwarded"]) == (False, "B", None)
    assert data["quota"]["used"] == antes["quota"]["used"] + 1
    despues = banco.user.get().to_dict()
    assert (despues["medalWallet"], despues["badgesTotal"]) == (antes["medalWallet"], antes["badgesTotal"])
    assert medallas(banco, CINCO) == [] and respuesta(banco, CINCO).to_dict()["correct"] is False


def test_tiempo_desde_delivered_at_e_histograma(banco):
    """T-28 y T-30: el tiempo es la hora de la API menos deliveredAt; el elapsedMs y el sessionId que mande la app
    se aceptan y no se usan."""
    ref = banco.db.document(f"questions/{CINCO}")
    antes = ref.get().to_dict()["stats"]
    pendiente(banco, CINCO, segundos=35)
    assert responder(banco, CINCO, "B", elapsedMs=1_000, sessionId="ses_demo").status_code == 200
    elapsed = respuesta(banco, CINCO).to_dict()["elapsedMs"]
    assert 35_000 <= elapsed < 45_000, elapsed
    stats = ref.get().to_dict()["stats"]
    assert (stats["timesAnswered"], stats["timesCorrect"], stats["sumElapsedMs"]) == \
        (antes["timesAnswered"] + 1, antes["timesCorrect"] + 1, antes["sumElapsedMs"] + elapsed)
    assert stats["elapsedBuckets"] == {**antes["elapsedBuckets"], "lt45": antes["elapsedBuckets"]["lt45"] + 1}


def test_percentil_sin_cohorte_y_con_datos(banco):
    pendiente(banco, CUATRO)
    assert responder(banco, CUATRO, "A").json()["data"]["cohortPercentile"] is None, "sin cinco respuestas previas"
    assert respuesta(banco, CUATRO).to_dict()["cohortPercentile"] is None
    # Ejemplo de ADR-87: 2 en lt20, 3 en lt30 y 1 en lt60. 25 s cae en lt30: 100 × (1 + 3/2) / 6 = 42.
    banco.db.document(f"questions/{CINCO}").update({"stats.elapsedBuckets.lt20": 2, "stats.elapsedBuckets.lt30": 3,
                                                     "stats.elapsedBuckets.lt60": 1})
    pendiente(banco, CINCO, segundos=25)
    assert responder(banco, CINCO, "B").json()["data"]["cohortPercentile"] == 42
    assert respuesta(banco, CINCO).to_dict()["cohortPercentile"] == 42


def test_ya_respondida(banco):
    pendiente(banco, CINCO)
    assert responder(banco, CINCO, "B").status_code == 200
    usuario = banco.user.get().to_dict()
    # La recién respondida y una del seed, aunque la letra sea inválida: ALREADY_ANSWERED va antes que la letra.
    for question_id, letra in ((CINCO, "B"), (RESPONDIDA, "B"), (CINCO, "Z")):
        assert error(responder(banco, question_id, letra)) == (409, "ALREADY_ANSWERED"), (question_id, letra)
    assert banco.user.get().to_dict() == usuario, "no descuenta ni da medallas otra vez"
    assert len(medallas(banco, CINCO)) == 1


def test_letra_que_no_existe_en_la_pregunta(banco):
    """ADR-80: A a D con cuatro alternativas y A a E con cinco."""
    pendiente(banco, CUATRO)
    for letra in ("E", "Z", "a", ""):
        assert error(responder(banco, CUATRO, letra)) == (400, "INVALID_OPTION"), letra
    pendiente(banco, CINCO)
    assert error(responder(banco, CINCO, "F")) == (400, "INVALID_OPTION")
    assert banco.user.get().to_dict()["quota"]["used"] == 5 and not respuesta(banco, CINCO).exists, "no registra nada"
    res = responder(banco, CINCO, "E")
    assert res.status_code == 200 and res.json()["data"]["correct"] is False, "E existe con cinco alternativas"


def test_solo_se_responde_la_pendiente(banco):
    """ADR-86: otra pregunta da NOT_FOUND, exista o no, como GET /questions/{id} (ADR-85)."""
    # En el seed no hay pendiente: la última pregunta del alumno ya está respondida.
    assert error(responder(banco, CINCO, "B")) == (404, "NOT_FOUND")
    pendiente(banco, CINCO)
    estado = banco.estado.get().to_dict()
    otra = responder(banco, CUATRO, "Z")  # el ID va antes que la letra
    inexistente = responder(banco, "qst_0000000000", "A")
    for res in (otra, inexistente):
        assert error(res) == (404, "NOT_FOUND")
    assert otra.json()["error"] == inexistente.json()["error"], "no confirma que la pregunta existe"
    assert banco.estado.get().to_dict() == estado and not respuesta(banco, CUATRO).exists


def test_una_pendiente_que_dejo_de_estar_publicada(banco):
    pendiente(banco, CINCO)
    banco.db.document(f"questions/{CINCO}").update({"status": "retired"})
    assert error(responder(banco, CINCO, "B")) == (404, "NOT_FOUND")


def test_cuota_al_tope(banco):
    banco.user.update({"quota.used": 10})
    pendiente(banco, CINCO)
    assert error(responder(banco, CINCO, "F")) == (400, "INVALID_OPTION"), "la letra va antes que la cuota"
    assert error(responder(banco, CINCO, "B")) == (422, "QUOTA_DAILY_LIMIT")
    assert banco.user.get().to_dict()["quota"]["used"] == 10 and not respuesta(banco, CINCO).exists
    assert banco.estado.get().to_dict()["lastQuestionId"] == CINCO, "sigue pendiente"


def test_la_cuota_se_reinicia_al_responder_otro_dia(banco):
    banco.user.update({"quota.date": "2020-01-01", "quota.used": 10, "quota.max": 15})
    pendiente(banco, CINCO)
    assert responder(banco, CINCO, "B").json()["data"]["quota"] == {"used": 1, "max": 10, "unlimited": False}
    assert banco.user.get().to_dict()["quota"]["date"] == quota_day()


def test_dominio_de_la_habilidad(banco):
    habilidad = banco.user.collection("skillMastery").document("sk_demo_m1_operatoria")
    antes = habilidad.get().to_dict()
    pendiente(banco, CINCO)
    responder(banco, CINCO, "D")
    despues = habilidad.get().to_dict()
    assert (despues["correct"], despues["total"], despues["testId"]) == (antes["correct"], antes["total"] + 1, "m1")
    assert despues["percent"] == round(100 * despues["correct"] / despues["total"])
    # La primera respuesta de una habilidad crea su documento.
    nueva = banco.user.collection("skillMastery").document("sk_demo_m1_ecuaciones")
    assert not nueva.get().exists
    pendiente(banco, CUATRO)
    responder(banco, CUATRO, "A")
    doc = nueva.get().to_dict()
    assert doc["updatedAt"] and {**doc, "updatedAt": None} == {"testId": "m1", "correct": 1, "total": 1, "percent": 100,
                                                               "level": 1, "status": "in_progress", "updatedAt": None}


def test_despues_de_responder_llega_otra_pregunta(banco):
    """CP-03: la respondida deja de estar pendiente y GET /practice/next entrega otra."""
    primera = banco.cliente.get(NEXT, headers=BEARER).json()["data"]
    assert responder(banco, primera["id"], "A").status_code == 200
    siguiente = banco.cliente.get(NEXT, headers=BEARER).json()
    assert siguiente["data"]["id"] != primera["id"]
    assert siguiente["data"]["progress"]["current"] == primera["progress"]["current"] + 1
    assert siguiente["meta"]["quota"]["used"] == 6
    vista = banco.cliente.get(f"/api/v1/questions/{primera['id']}", headers=BEARER).json()["data"]
    assert vista["deliveredAt"] is None, "la respondida se puede ver, sin hora de entrega"


def test_envios_simultaneos_registran_uno_y_rechazan_el_otro(banco):
    """Dos envíos a la vez de la misma pendiente: uno se registra y el otro, al reintentar tras el aborto de su
    transacción, da ALREADY_ANSWERED (ADR-86)."""
    pendiente(banco, CINCO)

    async def enviar():
        db = firestore.AsyncClient(project=banco.db.project)
        alumno = {"id": banco.user.id}
        return await asyncio.gather(*(register_answer(db, alumno, CINCO, "B") for _ in range(2)),
                                    return_exceptions=True)

    resultados = asyncio.run(enviar())
    registradas = [r for r in resultados if isinstance(r, dict)]
    rechazadas = [r for r in resultados if isinstance(r, ApiError)]
    assert len(registradas) == 1 and len(rechazadas) == 1, resultados
    assert rechazadas[0].code == "ALREADY_ANSWERED"
    assert len(medallas(banco, CINCO)) == 1 and banco.user.get().to_dict()["quota"]["used"] == 6


def test_reintentos_agotados_dan_conflict_y_no_registran(banco, monkeypatch):
    """Si Firestore aborta la transacción en cada intento, la API responde CONFLICT 409 con el envelope, nunca 500."""
    commits = []

    async def abortar(self, *_a, **_k):
        commits.append(1)
        raise exceptions.Aborted("contención simulada")

    monkeypatch.setattr(AsyncTransaction, "_commit", abortar)
    monkeypatch.setattr(answers, "RETRY_WAIT", 0)
    pendiente(banco, CINCO)
    res = responder(banco, CINCO, "B")
    assert error(res) == (409, "CONFLICT") and res.json()["data"] is None and res.json()["error"]["message"]
    assert len(commits) == answers.ANSWER_ATTEMPTS
    assert not respuesta(banco, CINCO).exists and banco.estado.get().to_dict()["lastQuestionId"] == CINCO
