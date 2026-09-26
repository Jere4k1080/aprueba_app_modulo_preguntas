"""Port de backend/test/health.test.js: las diez pruebas, una función por prueba. La 08, que exigía
JWT_SECRET en producción, prueba ahora Firebase Admin."""
import asyncio
import base64
import json
import os
import re
from types import SimpleNamespace

import firebase_admin
import google.auth
import pytest
from fastapi.testclient import TestClient
from firebase_admin import auth as firebase_auth
from firebase_admin import credentials as firebase_credentials

import app.db.firestore as firestore_db
import app.seed as seed
from app.core.config import get_settings
from app.core.errors import ERROR_STATUS, MESSAGES, ApiError
from app.main import app, create_app
from app.services.questions import ELAPSED_BUCKETS, calculate_cohort_percentile, sanitize_question

client = TestClient(app)


def test_01_sanitize_question_elimina_correct_answer_y_explanation():
    raw = {
        "id": "q_test_01",
        "statement": "¿Cuál es la capital de Chile?",
        "options": ["Santiago", "Lima", "Bogotá", "Buenos Aires"],
        "correctAnswer": "A",
        "explanation": "Santiago fue fundada en 1541...",
    }
    sanitized = sanitize_question(raw)
    assert sanitized["id"] == "q_test_01"
    assert "correctAnswer" not in sanitized
    assert "explanation" not in sanitized
    assert raw["correctAnswer"] == "A", "el objeto original no debe mutar"
    assert sanitize_question(None) is None


def test_02_calculate_cohort_percentile():
    thresholds = {"p25": 15000, "p50": 25000, "p75": 45000, "p90": 60000}
    assert calculate_cohort_percentile(thresholds, 10000) == 90
    assert calculate_cohort_percentile(thresholds, 20000) == 75
    assert calculate_cohort_percentile(thresholds, 40000) == 50
    assert calculate_cohort_percentile(thresholds, 55000) == 25
    assert calculate_cohort_percentile(thresholds, 70000) == 10
    assert calculate_cohort_percentile(None, 10000) == 50
    assert calculate_cohort_percentile(thresholds, "10000") == 50
    # Un documento mal cargado no revienta: umbral nulo o de texto toma su valor por defecto.
    assert calculate_cohort_percentile({**thresholds, "p25": None}, 10000) == 90
    assert calculate_cohort_percentile({"p90": "60000"}, 59000) == 25
    assert calculate_cohort_percentile(0, 10000) == 50


def test_03_catalogo_de_errores():
    err = ApiError(422, "QUOTA_BASE_REACHED")
    assert (err.status, err.code) == (422, "QUOTA_BASE_REACHED")
    # Como AppError en Node, un código del catálogo no puede salir con otro status.
    with pytest.raises(ValueError, match="QUOTA_BASE_REACHED va con status 422"):
        ApiError(400, "QUOTA_BASE_REACHED")
    assert ERROR_STATUS["QUOTA_DAILY_LIMIT"] == 422
    assert ERROR_STATUS["NOT_FOUND"] == 404
    assert set(MESSAGES) == set(ERROR_STATUS)
    for code, textos in MESSAGES.items():
        assert textos.get("es") and textos.get("en"), f"{code}: falta es o en"


def test_04_health_responde_envelope_con_request_id():
    res = client.get("/api/v1/health")
    assert res.status_code == 200
    body = res.json()
    assert body["error"] is None
    assert re.fullmatch(r"req_[0-9a-f]{12}", body["meta"]["requestId"])
    assert res.headers["x-request-id"] == body["meta"]["requestId"]
    assert re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z", body["meta"]["timestamp"])
    data = body["data"]
    assert data["status"] == "ok"
    assert data["service"] == "aprueba-questions-backend"
    assert data["version"] == "1.0.0"
    assert data["environment"] == "local"
    assert isinstance(data["uptimeSeconds"], int)


def test_05_ruta_inexistente_da_404_not_found():
    res = client.get("/api/v1/unknown-endpoint")
    assert res.status_code == 404
    body = res.json()
    assert body["data"] is None
    assert body["error"]["code"] == "NOT_FOUND"
    assert body["error"]["details"] == []
    assert body["meta"]["requestId"].startswith("req_")


def test_06_cors_lista_exacta_patron_y_solicitud_previa():
    def origin_of(res):
        return res.headers.get("access-control-allow-origin")

    ok = client.get("/api/v1/health", headers={"Origin": "https://app.aprueba.test"})
    assert origin_of(ok) == "https://app.aprueba.test"
    preview = client.get("/api/v1/health", headers={"Origin": "https://aprueba-pr-12.vercel.app"})
    assert origin_of(preview) == "https://aprueba-pr-12.vercel.app"
    denied = client.get("/api/v1/health", headers={"Origin": "https://app.aprueba.test.evil.example"})
    assert origin_of(denied) is None

    preflight = client.options("/api/v1/health", headers={
        "Origin": "https://app.aprueba.test",
        "Access-Control-Request-Method": "GET",
        "Access-Control-Request-Headers": "Authorization",
    })
    # Starlette responde 200 a la solicitud previa permitida; Express respondía 204.
    assert preflight.status_code == 200
    assert origin_of(preflight) == "https://app.aprueba.test"
    assert "access-control-allow-credentials" not in preflight.headers
    assert "authorization" in preflight.headers["access-control-allow-headers"].lower()

    # La solicitud previa de un origen no permitido recibe 400 en texto plano y sin cabecera de origen.
    rejected = client.options("/api/v1/health", headers={
        "Origin": "https://app.aprueba.test.evil.example",
        "Access-Control-Request-Method": "GET",
    })
    assert rejected.status_code == 400
    assert origin_of(rejected) is None


def test_07_credenciales_de_firestore(monkeypatch):
    creados = []
    monkeypatch.setattr(firestore_db, "AsyncClient", lambda **kw: creados.append(kw) or kw)
    monkeypatch.setattr(firestore_db, "service_account", SimpleNamespace(Credentials=SimpleNamespace(
        from_service_account_info=lambda info: {"project_id": info["project_id"]})))

    def abrir(**env):
        for name in ("FIRESTORE_EMULATOR_HOST", "FIRESTORE_EMULATOR_PROJECT_ID", "FIREBASE_SERVICE_ACCOUNT_BASE64",
                     "FIREBASE_PROJECT_ID"):
            if name in env:
                monkeypatch.setenv(name, env[name])
            else:
                monkeypatch.delenv(name, raising=False)
        get_settings.cache_clear()
        monkeypatch.setattr(firestore_db, "_client", None)
        creados.clear()
        firestore_db.get_db()
        firestore_db.get_db()
        return list(creados)

    # El emulador tiene prioridad aunque el base64 sea inválido, y el cliente se crea una sola vez.
    assert abrir(FIRESTORE_EMULATOR_HOST="127.0.0.1:8080", FIREBASE_SERVICE_ACCOUNT_BASE64="invalid") == [
        {"project": "demo-aprueba"}]
    # En el emulador Firestore usa su proyecto demo-; FIREBASE_PROJECT_ID solo valida tokens (ADR-49).
    assert abrir(FIRESTORE_EMULATOR_HOST="127.0.0.1:8080", FIREBASE_PROJECT_ID="aprueba-app-modulo-preguntas") == [
        {"project": "demo-aprueba"}]
    assert abrir(FIRESTORE_EMULATOR_HOST="127.0.0.1:8080", FIRESTORE_EMULATOR_PROJECT_ID="demo-otro") == [
        {"project": "demo-otro"}]

    cuenta = base64.b64encode(json.dumps({"project_id": "aprueba-test", "k": ">>>???x"}).encode()).decode()
    sin_relleno, url_segura = cuenta.rstrip("="), cuenta.replace("+", "-").replace("/", "_")
    assert cuenta not in (sin_relleno, url_segura)
    # Como Buffer.from(x, 'base64') de Node: con relleno, sin relleno y con alfabeto URL seguro.
    for valor in (cuenta, sin_relleno, url_segura):
        assert abrir(FIREBASE_SERVICE_ACCOUNT_BASE64=valor) == [
            {"project": "aprueba-test", "credentials": {"project_id": "aprueba-test"}}]
    # Con cuenta de servicio, Firestore usa el proyecto de la cuenta aunque FIREBASE_PROJECT_ID diga otro.
    assert abrir(FIREBASE_SERVICE_ACCOUNT_BASE64=cuenta, FIREBASE_PROJECT_ID="otro-proyecto") == [
        {"project": "aprueba-test", "credentials": {"project_id": "aprueba-test"}}]
    # Vacía cuenta como ausente, y se retira para que la librería no entre en modo emulador.
    assert abrir(FIRESTORE_EMULATOR_HOST="", FIREBASE_SERVICE_ACCOUNT_BASE64=cuenta) == [
        {"project": "aprueba-test", "credentials": {"project_id": "aprueba-test"}}]
    assert "FIRESTORE_EMULATOR_HOST" not in os.environ

    with pytest.raises(RuntimeError, match="no contiene un JSON válido"):
        abrir(FIREBASE_SERVICE_ACCOUNT_BASE64="invalid")
    with pytest.raises(RuntimeError, match="Configura FIRESTORE_EMULATOR_HOST o FIREBASE_SERVICE_ACCOUNT_BASE64"):
        abrir()


def test_08_firebase_admin_con_la_configuracion_de_firestore(monkeypatch):
    def sin_credenciales_predeterminadas(*args, **kwargs):
        raise AssertionError("firebase_admin no debe cargar las credenciales predeterminadas de Google")

    monkeypatch.setattr(google.auth, "default", sin_credenciales_predeterminadas)

    # Con el emulador arranca sin credenciales, y crear la app de nuevo reutiliza la de Firebase.
    # El proyecto demo- de Firestore no cambia el de Firebase Auth (ADR-49).
    monkeypatch.setenv("FIRESTORE_EMULATOR_PROJECT_ID", "demo-otro")
    firebase_admin.delete_app(firebase_admin.get_app())
    create_app()
    firebase_app = firebase_admin.get_app()
    create_app()
    assert firebase_admin.get_app() is firebase_app
    assert firebase_app.project_id == "aprueba-app-modulo-preguntas"
    # verify_id_token real: un token mal formado se rechaza sin red y sin buscar credenciales.
    with pytest.raises(firebase_auth.InvalidIdTokenError):
        firebase_auth.verify_id_token("no.es.jwt", app=firebase_app)

    # Sin emulador usa la misma cuenta de servicio que Firestore, con la misma decodificación.
    firebase_admin.delete_app(firebase_app)
    monkeypatch.delenv("FIRESTORE_EMULATOR_HOST")
    info = {"type": "service_account", "project_id": "aprueba-test"}
    monkeypatch.setenv("FIREBASE_SERVICE_ACCOUNT_BASE64", base64.b64encode(json.dumps(info).encode()).decode().rstrip("="))
    monkeypatch.setattr(firebase_credentials, "Certificate", lambda cert: ("certificado", cert))
    monkeypatch.setattr(firebase_admin, "initialize_app", lambda cred, options: (cred, options))
    get_settings.cache_clear()
    # httpTimeout: sin él la descarga de certificados espera 120 s antes del 503.
    assert firestore_db.get_firebase_app() == (("certificado", info), {"projectId": "aprueba-test", "httpTimeout": 10})

    # Con el emulador de Auth, firebase_admin acepta tokens sin firma: solo en local y con el de Firestore.
    monkeypatch.setenv("FIREBASE_AUTH_EMULATOR_HOST", "127.0.0.1:9099")
    solo_local = "FIREBASE_AUTH_EMULATOR_HOST solo se admite con APP_ENV=local y FIRESTORE_EMULATOR_HOST"
    with pytest.raises(RuntimeError, match=solo_local):
        firestore_db.get_firebase_app()
    monkeypatch.delenv("FIREBASE_SERVICE_ACCOUNT_BASE64")
    monkeypatch.setenv("FIRESTORE_EMULATOR_HOST", "127.0.0.1:8080")
    monkeypatch.setenv("APP_ENV", "staging")
    get_settings.cache_clear()
    with pytest.raises(RuntimeError, match=solo_local):
        firestore_db.get_firebase_app()
    monkeypatch.setenv("APP_ENV", "local")
    get_settings.cache_clear()
    assert firestore_db.get_firebase_app()[1]["projectId"] == "aprueba-app-modulo-preguntas"

    monkeypatch.delenv("FIREBASE_AUTH_EMULATOR_HOST")
    monkeypatch.delenv("FIRESTORE_EMULATOR_HOST")
    get_settings.cache_clear()
    with pytest.raises(RuntimeError, match="Configura FIRESTORE_EMULATOR_HOST o FIREBASE_SERVICE_ACCOUNT_BASE64"):
        firestore_db.get_firebase_app()


def test_09_seed_remoto_exige_seed_allow_remote(monkeypatch):
    monkeypatch.delenv("FIRESTORE_EMULATOR_HOST")
    monkeypatch.delenv("SEED_ALLOW_REMOTE", raising=False)
    abiertos = []
    monkeypatch.setattr(seed, "get_db", lambda: abiertos.append(1))
    with pytest.raises(RuntimeError, match="Seed remoto bloqueado"):
        asyncio.run(seed.seed_database())
    assert abiertos == [], "no debe abrir Firestore antes de verificar el permiso"


def test_10_banco_de_demostracion_consistente():
    tests, skills, questions, plans = seed.load("tests"), seed.load("skills"), seed.load("questions"), seed.load("plans")
    users, answers, corrections = seed.load("users"), seed.load("answers"), seed.load("corrections")

    test_by_id = {t["id"]: t for t in tests}
    skill_by_id = {s["id"]: s for s in skills}
    q_by_id = {q["id"]: q for q in questions}
    assert (len(test_by_id), len(skill_by_id), len(q_by_id)) == (len(tests), len(skills), len(questions)), "IDs repetidos"
    for t in tests:
        assert t["axes"] and t["active"] and (t["countryId"], t["examId"]) == ("cl", "cl_paes"), f"{t['id']}: prueba incompleta"
        assert t["nameLower"] == t["label"].lower(), f"{t['id']}: nameLower no sale de label"
    assert sorted(t["order"] for t in tests) == list(range(1, len(tests) + 1)), "order repetido o con saltos"
    for s in skills:
        assert s["testId"] in test_by_id and s["axis"] in test_by_id[s["testId"]]["axes"], f"{s['id']}: prueba o eje inválido"
        assert 1 <= s["level"] <= s["maxLevel"], f"{s['id']}: nivel fuera de rango"
        for p in s["prerequisites"]:
            assert p in skill_by_id and p != s["id"], f"{s['id']}: prerrequisito inválido {p}"

    vacias = {"timesAnswered": 0, "timesCorrect": 0, "sumElapsedMs": 0,
              "elapsedBuckets": dict.fromkeys((tramo for tramo, _ in ELAPSED_BUCKETS), 0)}
    celdas = set()
    for q in questions:
        assert re.fullmatch(r"qst_[0-9a-f]{10}", q["id"]), f"{q['id']}: ID fuera del formato qst_ de la administración"
        assert q["testId"] in test_by_id and q["axis"] in test_by_id[q["testId"]]["axes"], f"{q['id']}: prueba o eje inválido"
        assert q["difficulty"] in ("d1", "d2", "d3", "d4"), f"{q['id']}: dificultad inválida"
        assert 4 <= len(q["options"]) <= 5 and len(set(q["options"])) == len(q["options"]), f"{q['id']}: alternativas inválidas"
        assert q["correctAnswer"] in "ABCDE"[:len(q["options"])], f"{q['id']}: correctAnswer fuera de las alternativas"
        assert skill_by_id.get(q["skillId"], {}).get("testId") == q["testId"], f"{q['id']}: skillId inexistente o de otra prueba"
        assert q["requiredSkillText"] == skill_by_id[q["skillId"]]["name"], f"{q['id']}: requiredSkillText distinto de la habilidad"
        # La administración corrige explanation como texto de 10 a 4000 caracteres.
        assert isinstance(q["explanation"], str) and 10 <= len(q["explanation"]) <= 4000, f"{q['id']}: explicación inválida"
        # El generador exige que published implique approved.
        assert (q["status"], q["reviewStatus"]) == ("published", "approved"), f"{q['id']}: publicada sin aprobar"
        assert (q["countryId"], q["examId"], q["origin"], q["version"], q["source"]) == ("cl", "cl_paes", "manual", 1, "seed_demo")
        assert 0 <= q["randomKey"] < 1 and q["flagCount"] == 0 and q["stats"] == vacias, f"{q['id']}: estado inicial inválido"
        celdas.add(f"{q['testId']}/{q['difficulty']}")
    assert len(celdas) == 20, "Faltan preguntas en alguna combinación de prueba y dificultad"
    assert len({q["randomKey"] for q in questions}) == len(questions), "randomKey repetido"

    assert [p["id"] for p in plans] == ["free", "uni", "all"], "faltan los planes de sistema de la administración"
    for p in plans:
        assert set(p["name"]) == {"es", "en"} and p["system"] is True and p["currency"] in ("USD", "CLP"), f"{p['id']}: forma inválida"
        assert isinstance(p["limits"]["qDay"], int) and p["limits"]["qDay"] >= 0, f"{p['id']}: qDay inválido"
        assert all(isinstance(p["badges"][k], int) for k in ("login", "purchase", "correct")), f"{p['id']}: badges inválidos"
    assert plans[0]["limits"]["qDay"] > 0, "el plan gratuito necesita una base de cuota"

    assert sorted(u["role"] for u in users) == ["demo", "nuevo"]
    for u in users:
        # El resto del documento lo pone el alta (ADR-66); aquí va solo la cuenta y lo propio de la demo.
        assert set(u) == {"role", "email", "name", "signInProvider", "locale", "selectedTests"}, f"{u['role']}: campos de más"
        assert u["signInProvider"] == "password" and u["locale"] in ("es", "en"), f"{u['role']}: cuenta inválida"
        assert all(t in test_by_id for t in u["selectedTests"]), f"{u['role']}: prueba seleccionada inexistente"
    assert set(answers) == {"demo"}, "solo aprueba@demo.cl tiene respuestas; aprueba2@demo.cl parte de cero"
    demo = next(u for u in users if u["role"] == "demo")
    respondidas = {a["questionId"] for a in answers["demo"]}
    assert len(respondidas) == len(answers["demo"]), "una pregunta respondida dos veces"
    for a in answers["demo"]:
        q = q_by_id[a["questionId"]]
        assert q["testId"] in demo["selectedTests"] and a["selected"] in "ABCDE"[:len(q["options"])] and a["elapsedMs"] > 0
    assert any(q["testId"] in demo["selectedTests"] and q["id"] not in respondidas for q in questions), \
        "a aprueba@demo.cl no le quedan preguntas por responder"
    for c in corrections:
        assert re.fullmatch(r"cor_[0-9a-f]{10}", c["id"]) and c["role"] == "demo", f"{c['id']}: ID o cuenta inválida"
        assert c["questionId"] in respondidas and c["proposedAnswer"] in "ABCDE" and c["reason"], f"{c['id']}: solicitud inválida"
