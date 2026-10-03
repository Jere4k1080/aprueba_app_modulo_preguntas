"""Modelo alineado con la administración (Entrega A): IDs, histograma y seed."""
import asyncio
import math
import re
from collections import Counter
from datetime import datetime
from fractions import Fraction

import pytest
from google.cloud.firestore import SERVER_TIMESTAMP, AsyncClient

import app.db.firestore as firestore_db
import app.seed as seed
from app.core.config import get_settings
from app.db.firestore import USER_ID_PATTERN, user_doc_id
from app.core.errors import ApiError
from app.services.practice import check_quota
from app.services.questions import ELAPSED_BUCKETS, elapsed_bucket
from app.services.users import TIERS, new_user, quota_max
from emulador import HOST, activo, vaciar

# UID ficticios con el largo de un UID de Firebase (28 caracteres).
UIDS = {"demo": "demoUid000000000000000000001", "nuevo": "demoUid000000000000000000002"}


def test_id_de_users_con_el_patron_de_la_administracion():
    # Un UID de Firebase tiene 28 caracteres: con usr_ cabe en el patrón de GET y PATCH /admin/users/{id}.
    for uid in UIDS.values():
        assert USER_ID_PATTERN.fullmatch(user_doc_id(uid))
    assert not USER_ID_PATTERN.fullmatch(UIDS["demo"]), "el UID solo no pasa: por eso lleva usr_"
    assert not USER_ID_PATTERN.fullmatch(user_doc_id("x" * 37)), "más de 36 caracteres tras usr_ no pasan"


def test_tramos_del_histograma():
    tramos = [tramo for tramo, _ in ELAPSED_BUCKETS]
    assert all(re.fullmatch(r"[a-z][a-z0-9]*", t) for t in tramos), "tramos que no sirven de ruta de campo en Firestore"
    casos = {0: "lt10", 9_999: "lt10", 10_000: "lt20", 44_999: "lt45", 45_000: "lt60", 119_999: "lt120",
             299_999: "lt300", 300_000: "gte300", 3_600_000: "gte300"}
    for ms, tramo in casos.items():
        assert elapsed_bucket(ms) == tramo, f"{ms} ms"


def test_alta_de_un_alumno():
    free = {"limits": {"qDay": 10}}
    u = new_user({"email": "Ana.Perez@Correo.cl", "firebase": {"sign_in_provider": "google.com"}}, "en", free, "2026-09-26")
    # Sin nombre en el token, el nombre sale del correo (ADR-66).
    assert (u["name"], u["nameLower"], u["emailLower"]) == ("Ana.Perez", "ana.perez", "ana.perez@correo.cl")
    assert (u["authProvider"], u["locale"], u["plan"], u["state"], u["country"]) == ("google", "en", "free", "active", "CL")
    assert u["quota"] == {"used": 0, "max": 10, "date": "2026-09-26", "bonusSchool": False, "bonusAddress": False,
                          "unlimited": False}
    assert u["medalWallet"] == dict.fromkeys(TIERS, 0) and u["badgesTotal"] == 0 and u["selectedTests"] == []
    assert not {"avatarColor", "theme", "planStatus", "dailyReminder"} & set(u), "campos de módulos fuera del alcance"
    assert new_user({"email": "a@b.cl", "name": "Ana"}, "es", free, "x")["name"] == "Ana"
    ilimitado = new_user({"email": "a@b.cl"}, "es", {"limits": {"qDay": 0}}, "x")["quota"]
    assert (ilimitado["max"], ilimitado["unlimited"]) == (0, True)


def test_cuota_con_qday_como_tope():
    """ADR-76: base 10 más 5 por cada bono reclamado, sin pasar del tope qDay del plan; qDay 0 es ilimitado."""
    free = {"limits": {"qDay": 20}}
    assert quota_max(free) == 10, "sin bonos"
    assert quota_max(free, bonus_school=True) == quota_max(free, bonus_address=True) == 15, "con un bono"
    assert quota_max(free, True, True) == 20, "con los dos"
    assert quota_max({"limits": {"qDay": 12}}, True, True) == 12 and quota_max({"limits": {"qDay": 8}}) == 8, "el tope manda"
    assert quota_max({"limits": {"qDay": 0}}, True, True) == 0, "plan ilimitado"


def _error_de_cuota(quota: dict, plan: dict) -> str | None:
    try:
        check_quota(quota, plan)
    except ApiError as e:
        return e.code
    return None


def test_cuota_base_alcanzada_o_limite_diario():
    free = {"limits": {"qDay": 20}}
    assert _error_de_cuota({"used": 9, "max": 10}, free) is None, "quedan preguntas"
    assert _error_de_cuota({"used": 10, "max": 10}, free) == "QUOTA_BASE_REACHED", "un bono todavía suma"
    assert _error_de_cuota({"used": 15, "max": 15, "bonusSchool": True}, free) == "QUOTA_BASE_REACHED"
    assert _error_de_cuota({"used": 20, "max": 20, "bonusSchool": True, "bonusAddress": True}, free) == "QUOTA_DAILY_LIMIT"
    # Con el máximo en el tope ningún bono suma, aunque quede uno sin reclamar: no se ofrece el desbloqueo.
    assert _error_de_cuota({"used": 10, "max": 10}, {"limits": {"qDay": 10}}) == "QUOTA_DAILY_LIMIT"
    assert _error_de_cuota({"used": 80, "max": 0, "unlimited": True}, {"limits": {"qDay": 0}}) is None, "ilimitado"


def test_seed_exige_los_uid_de_demostracion(monkeypatch):
    abiertos = []
    monkeypatch.setattr(seed, "get_db", lambda: abiertos.append(1))
    monkeypatch.setenv("SEED_DEMO_NEW_UID", UIDS["nuevo"])
    with pytest.raises(RuntimeError, match="Falta SEED_DEMO_UID"):
        asyncio.run(seed.seed_database())
    monkeypatch.setenv("SEED_DEMO_UID", "x" * 37)
    get_settings.cache_clear()
    with pytest.raises(RuntimeError, match="SEED_DEMO_UID no da un ID de users"):
        asyncio.run(seed.seed_database())
    assert abiertos == [], "no debe abrir Firestore antes de validar los UID"


def test_documentos_del_seed_para_la_administracion():
    docs = seed.build_documents(UIDS, "2026-09-25")
    rutas = [ruta for ruta, _ in docs]
    por_ruta = dict(docs)
    assert len(rutas) == len(set(rutas)), "dos documentos con la misma ruta"
    assert not any("medalLedger" in r or r.startswith("answers/") or "id" in d for r, d in docs), \
        "quedan restos del modelo anterior"

    demo, nuevo = (user_doc_id(UIDS[r]) for r in ("demo", "nuevo"))
    plans = {r.split("/")[1]: d for r, d in docs if r.startswith("plans/")}
    assert all(p["nameLower"] == p["name"]["es"].lower() for p in plans.values()), "plans sin nameLower"
    assert plans["free"]["limits"]["qDay"] == 20, "regla de negocio 1: qDay del plan gratuito es el tope de 20 (ADR-76)"
    for doc_id in (demo, nuevo):
        u = por_ruta[f"users/{doc_id}"]
        # La consola lee name, email y createdAt con acceso obligatorio y ordena por nameLower,
        # lastActivityAt, badgesTotal y createdAt.
        for campo in ("name", "nameLower", "email", "emailLower", "plan", "state", "country", "lastActivityAt",
                      "medalWallet", "badgesTotal", "createdAt", "subscriptionId", "authProvider", "streak", "locale",
                      "quota", "selectedTests", "practiceFormat", "difficulty"):
            assert campo in u, f"{doc_id}: falta {campo}"
        assert u["createdAt"] is SERVER_TIMESTAMP and u["lastActivityAt"] is SERVER_TIMESTAMP
        assert set(u["medalWallet"]) == {"bronze", "silver", "gold", "diamond", "platinum"}
        assert u["badgesTotal"] == sum(u["medalWallet"].values())
        assert u["quota"]["max"] == quota_max(plans[u["plan"]]) == 10 and u["quota"]["date"] == "2026-09-25"

    # El seed crea a los alumnos con la función del alta y agrega solo lo propio de la demo (ADR-66):
    # aprueba2@demo.cl, que no respondió nada, es el alta más sus pruebas elegidas.
    cuenta = next(u for u in seed.load("users") if u["role"] == "nuevo")
    alta = new_user({"email": cuenta["email"], "name": cuenta["name"], "firebase": {"sign_in_provider": cuenta["signInProvider"]}},
                    cuenta["locale"], plans["free"], "2026-09-25")
    assert por_ruta[f"users/{nuevo}"] == {**alta, "selectedTests": cuenta["selectedTests"]}
    assert por_ruta[f"users/{nuevo}"]["name"] == "Estudiante Nuevo", "el nombre visible de la cuenta manda sobre el correo"

    respuestas = {r: d for r, d in docs if r.startswith(f"users/{demo}/answers/")}
    assert len(respuestas) == por_ruta[f"users/{demo}"]["quota"]["used"] == 5
    assert not any(r.startswith(f"users/{nuevo}/answers/") for r in rutas), "aprueba2@demo.cl parte de cero"
    assert por_ruta[f"users/{nuevo}"]["quota"]["used"] == 0 and por_ruta[f"users/{nuevo}"]["badgesTotal"] == 0
    assert por_ruta[f"users/{demo}/state/practice"]["answeredQuestionIds"] == [a["questionId"] for a in respuestas.values()]

    movimientos = [d for r, d in docs if r.startswith("medalTransactions/")]
    assert all(re.fullmatch(r"medalTransactions/mtx_[0-9a-f]{10}", r) for r in rutas if r.startswith("medalTransactions/"))
    assert len(movimientos) == sum(a["correct"] for a in respuestas.values())
    for m in movimientos:
        assert (m["userId"], m["tier"], m["reason"]) == (demo, "bronze", "answer_correct")
        assert m["amount"] == plans["free"]["badges"]["correct"] and m["refId"].startswith("qst_")
    assert por_ruta[f"users/{demo}"]["medalWallet"]["bronze"] == sum(m["amount"] for m in movimientos)

    preguntas = {r.split("/")[1]: d for r, d in docs if r.startswith("questions/")}
    for q_id, q in preguntas.items():
        suyas = [a for a in respuestas.values() if a["questionId"] == q_id]
        buckets = Counter(elapsed_bucket(a["elapsedMs"]) for a in suyas)
        assert q["stats"]["timesAnswered"] == len(suyas) and q["stats"]["timesCorrect"] == sum(a["correct"] for a in suyas)
        assert q["stats"]["sumElapsedMs"] == sum(a["elapsedMs"] for a in suyas)
        assert all(q["stats"]["elapsedBuckets"][c] == buckets[c] for c, _ in ELAPSED_BUCKETS), f"{q_id}: histograma"

    correcciones = {r: d for r, d in docs if r.startswith("corrections/")}
    assert correcciones and all(re.fullmatch(r"corrections/cor_[0-9a-f]{10}", r) for r in correcciones)
    for c in correcciones.values():
        # Campos que lee GET /admin/corrections de la administración, sin adaptaciones.
        for campo in ("userId", "userName", "questionId", "testId", "axis", "difficulty", "statementPreview",
                      "reason", "proposedAnswer", "state", "createdAt", "resolvedAt", "resolvedBy", "note", "rewardGranted"):
            assert campo in c, f"corrección sin {campo}"
        assert c["userId"] == demo and c["state"] == "pending" and c["createdAt"] is SERVER_TIMESTAMP
        assert c["reasonCode"] in ("wrong_answer", "ambiguous", "typo", "bad_explanation", "other"), "reasonCode de ADR-67"
        assert len(c["statementPreview"]) <= 120 and "\n" not in c["statementPreview"]
        assert preguntas[c["questionId"]]["flagCount"] == 1, "flagCount no cuenta la solicitud abierta"

    maestria = {r: d for r, d in docs if r.startswith(f"users/{demo}/skillMastery/")}
    assert sum(m["total"] for m in maestria.values()) == len(respuestas)
    assert all(m["percent"] == round(100 * m["correct"] / m["total"]) for m in maestria.values())


def test_modo_facsimil_segun_features():
    # ADR-70: el facsímil se permite si el plan incluye la funcionalidad con key mock_mode.
    docs = dict(seed.build_documents(UIDS, "2026-09-26"))
    facsim = [r.split("/")[1] for r, d in docs.items() if r.startswith("features/") and d["key"] == "mock_mode"]
    assert facsim == ["f2"]
    con_facsim = {r.split("/")[1] for r, d in docs.items() if r.startswith("plans/") and "f2" in d["features"]}
    assert con_facsim == {"all"}, "con los planes de ejemplo de la administración solo all incluye mock_mode"


PREGUNTAS = seed.load("questions")


def test_forma_de_las_preguntas_del_banco():
    ids = [q["id"] for q in PREGUNTAS]
    assert len(ids) == len(set(ids)) and all(re.fullmatch(r"qst_[0-9a-f]{10}", i) for i in ids)
    claves = [q["randomKey"] for q in PREGUNTAS]
    assert len(claves) == len(set(claves)) and all(0 <= k < 1 for k in claves), "randomKey repetido o fuera de rango"
    habilidades = {s["id"]: s for s in seed.load("skills")}
    ejes = {t["id"]: set(t["axes"]) for t in seed.load("tests")}
    for q in PREGUNTAS:
        assert len(set(q["options"])) == len(q["options"]) == 4 and q["correctAnswer"] in ("A", "B", "C", "D"), q["id"]
        assert q["axis"] in ejes[q["testId"]] and habilidades[q["skillId"]]["testId"] == q["testId"], q["id"]
        assert (q["status"], q["reviewStatus"], q["source"]) == ("published", "approved", "seed_demo"), q["id"]
        assert q["explanation"].startswith("1. ") and "\nVerificación: " in q["explanation"], q["id"]


def test_el_banco_alcanza_un_dia_de_cuota_en_d1():
    """Las cuentas de demostración practican lectora y m1 en d1. Con 10 preguntas o más en cada prueba,
    aprueba2@demo.cl completa la cuota del día, bonos incluidos, sin quedarse sin preguntas (ADR-73)."""
    for test in ("lectora", "m1"):
        assert sum(q["testId"] == test and q["difficulty"] == "d1" for q in PREGUNTAS) >= 10, test


def _valor(alternativa: str) -> Fraction:
    """Número de una alternativa: −4, 17/3, 8,5, $4.550, 10 cm o x = 6."""
    texto = re.sub(r"(?<=\d)\.(?=\d{3}(?!\d))", "", alternativa.replace("−", "-").replace("$", ""))  # punto de miles
    return Fraction(re.search(r"-?\d+(?:,\d+)?(?:/\d+)?", texto).group().replace(",", "."))


def _hipotenusa(a: int, b: int) -> Fraction:
    c = math.isqrt(a * a + b * b)
    assert c * c == a * a + b * b, "la hipotenusa no es entera"
    return Fraction(c)


# Respuesta de cada pregunta de m1 en d1, calculada desde el enunciado y sin mirar correctAnswer.
RESPUESTAS_M1_D1 = {
    "qst_9873643c47": 3 + 4 * 2 - Fraction(6, 3),                        # 3 + 4 · 2 − 6 ÷ 3
    "qst_31705f149a": Fraction(-8 + 5 * 3),                               # −8 + 5 · 3
    "qst_d410314561": Fraction(20 - (6 - 9) * 2),                         # 20 − (6 − 9) · 2
    "qst_a366f8d731": Fraction(25, 100) * 40,                             # el 25 % de 40 estudiantes
    "qst_59b7c06ed6": Fraction(12_500 - 4_750 - 3_200),                   # lo que le queda a Camila
    "qst_d156e63a9d": Fraction(17 - 5, 2),                                # 2x + 5 = 17
    "qst_d5d89dc1e5": Fraction(15, 3) + 2,                                # 3(x − 2) = 15
    "qst_f9b0162f63": Fraction(36, 1 + 2),                                # un número más su doble es 36
    "qst_a3b859282d": Fraction(5, 3 + 5 + 2),                             # bolita azul
    "qst_543c93e1d4": Fraction(sum(cara > 4 for cara in range(1, 7)), 6),  # dado mayor que 4
    "qst_7afdd2173d": _hipotenusa(6, 8),                                  # catetos de 6 y 8 cm
}


def test_respuestas_de_m1_en_d1_recalculadas():
    """En cada pregunta de m1 en d1 coincide con el cálculo una sola alternativa, y es la marcada."""
    m1_d1 = {q["id"]: q for q in PREGUNTAS if q["testId"] == "m1" and q["difficulty"] == "d1"}
    assert set(m1_d1) == set(RESPUESTAS_M1_D1), "cada pregunta de m1 en d1 necesita su cálculo"
    for q_id, valor in RESPUESTAS_M1_D1.items():
        q = m1_d1[q_id]
        coinciden = [letra for letra, alternativa in zip("ABCD", q["options"]) if _valor(alternativa) == valor]
        assert coinciden == [q["correctAnswer"]], f"{q_id}: coinciden {coinciden} y la marcada es {q['correctAnswer']}"


@pytest.mark.skipif(not activo(), reason=f"sin emulador de Firestore en {HOST}")
def test_seed_contra_el_emulador(monkeypatch):
    proyecto = "demo-pytest-seed"
    monkeypatch.setenv("FIRESTORE_EMULATOR_PROJECT_ID", proyecto)
    monkeypatch.setenv("SEED_DEMO_UID", UIDS["demo"])
    monkeypatch.setenv("SEED_DEMO_NEW_UID", UIDS["nuevo"])
    monkeypatch.setattr(firestore_db, "_client", None)
    get_settings.cache_clear()

    async def sembrar_y_leer():
        await seed.seed_database()
        db = AsyncClient(project=proyecto)
        conteo = {c: len([d async for d in db.collection(c).stream()])
                  for c in ("questions", "plans", "features", "users", "tests", "skills", "medalTransactions", "corrections")}
        demo = db.collection("users").document(user_doc_id(UIDS["demo"]))
        conteo["answers"] = len([d async for d in demo.collection("answers").stream()])
        usuario = (await demo.get()).to_dict()
        return conteo, usuario

    try:
        conteo, usuario = asyncio.run(sembrar_y_leer())
        assert conteo == {"questions": 40, "plans": 3, "features": 1, "users": 2, "tests": 5, "skills": 20,
                          "medalTransactions": 4, "corrections": 1, "answers": 5}
        assert isinstance(usuario["createdAt"], datetime) and isinstance(usuario["lastActivityAt"], datetime)
        assert usuario["badgesTotal"] == 4 and usuario["quota"]["used"] == 5
    finally:
        # Borra todo lo del proyecto de prueba en el emulador.
        vaciar(proyecto)
