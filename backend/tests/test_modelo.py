"""Modelo alineado con la administración (Entrega A): IDs, histograma y seed."""
import asyncio
import re
import socket
import urllib.request
from collections import Counter
from datetime import datetime

import pytest
from google.cloud.firestore import SERVER_TIMESTAMP, AsyncClient

import app.db.firestore as firestore_db
import app.seed as seed
from app.core.config import get_settings
from app.db.firestore import USER_ID_PATTERN, user_doc_id
from app.services.questions import ELAPSED_BUCKETS, elapsed_bucket

# UID ficticios con el largo de un UID de Firebase (28 caracteres).
UIDS = {"demo": "demoUid000000000000000000001", "nuevo": "demoUid000000000000000000002"}


def _emulador_activo() -> bool:
    try:
        socket.create_connection(("127.0.0.1", 8080), timeout=0.5).close()
        return True
    except OSError:
        return False


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
    assert plans["free"]["limits"]["qDay"] == 10, "regla de negocio 1: base de 10 en el plan gratuito (ADR-64)"
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
        assert u["quota"]["max"] == plans[u["plan"]]["limits"]["qDay"] and u["quota"]["date"] == "2026-09-25"

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


@pytest.mark.skipif(not _emulador_activo(), reason="emulador de Firestore apagado en 127.0.0.1:8080")
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
        assert conteo == {"questions": 20, "plans": 3, "features": 1, "users": 2, "tests": 5, "skills": 20,
                          "medalTransactions": 4, "corrections": 1, "answers": 5}
        assert isinstance(usuario["createdAt"], datetime) and isinstance(usuario["lastActivityAt"], datetime)
        assert usuario["badgesTotal"] == 4 and usuario["quota"]["used"] == 5
    finally:
        # Borra todo lo del proyecto de prueba en el emulador.
        pedido = urllib.request.Request(
            f"http://127.0.0.1:8080/emulator/v1/projects/{proyecto}/databases/(default)/documents", method="DELETE")
        urllib.request.urlopen(pedido, timeout=10).close()
